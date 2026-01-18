# frozen_string_literal: true

class KnowledgeExtractionTask < ApplicationTask
  # Multi-stage task for extracting entities and facts from card content.
  # Uses a hybrid approach: pattern extraction -> entity linking -> LLM extraction.
  #
  # Stages:
  # 1. ValidateInput - Find card and check preconditions
  # 2. PatternExtract - Fast pattern-based extraction
  # 3. LinkEntities - Match mentions to existing entities
  # 4. LlmExtract - Deep extraction using LLM (if enabled)
  # 5. PersistResults - Save entities, facts, and mentions
  # 6. Broadcast - Notify UI of completion

  STAGE_VALIDATING = 0
  STAGE_PATTERNS = 1
  STAGE_LINKING = 2
  STAGE_LLM = 3
  STAGE_PERSISTING = 4
  STAGE_COMPLETE = 5

  def stage_klass_sequence
    [
      ValidateInput,
      PatternExtract,
      LinkEntities,
      LlmExtract,
      PersistResults,
      Broadcast
    ]
  end

  def broadcast_stage_progress(stage_index)
    return unless card

    broadcast_replace(
      stream: "card_#{card.id}_knowledge",
      target: "card-#{card.id}-knowledge-extraction",
      partial: "cards/knowledge_extraction_loading",
      locals: { card: card, stage: stage_index }
    )
  end

  # Stage 1: Validate input
  class ValidateInput < TaskFrame::Stage
    include FindsCard

    def perform_work
      result = find_card
      return result if result.failure?

      card = result.value![:card]
      board = card.board

      # Ensure at least one domain exists
      if board.domains.empty?
        board.domains.create!(
          name: "General",
          description: "Auto-created domain for extracted knowledge",
          system_generated: true,
          color: "#6B7280"
        )
      end

      task.broadcast_stage_progress(KnowledgeExtractionTask::STAGE_PATTERNS)

      Success(
        card: card,
        board: board,
        default_domain: board.domains.first,
        existing_entities: board.entities.to_a
      )
    end
  end

  # Stage 2: Pattern-based extraction
  class PatternExtract < TaskFrame::Stage
    def perform_work
      card = task.card
      extractor = CardIntelligence::PatternExtractor.new

      begin
        result = extractor.extract(card)
        task.broadcast_stage_progress(KnowledgeExtractionTask::STAGE_LINKING)

        Success(
          entities: result[:entities] || [],
          facts: result[:facts] || [],
          stage: name
        )
      rescue StandardError => e
        # Pattern extraction is non-critical, continue with empty results
        Success(entities: [], facts: [], error: e.message, stage: name)
      end
    end
  end

  # Stage 3: Entity linking
  class LinkEntities < TaskFrame::Stage
    def perform_work
      input = task.result_for(ValidateInput)
      card = task.card
      linker = CardIntelligence::EntityLinker.new

      begin
        result = linker.link(card, input[:existing_entities])
        task.broadcast_stage_progress(KnowledgeExtractionTask::STAGE_LLM)

        Success(
          mentions: result[:mentions] || [],
          stage: name
        )
      rescue StandardError => e
        Success(mentions: [], error: e.message, stage: name)
      end
    end
  end

  # Stage 4: LLM-based extraction
  class LlmExtract < TaskFrame::Stage
    EXTRACTION_PROMPT = <<~PROMPT
      Extract entities and facts from this kanban card content.

      ## Card Information
      Title: %{title}
      Description: %{description}

      ## Existing Entities (reuse these if mentioned)
      %{existing_entities}

      ## Existing Domains
      %{existing_domains}

      ## Instructions
      Extract:
      1. **Entities**: Named things mentioned in the card
         - People (names, roles)
         - Systems (services, APIs, databases)
         - Concepts (technologies, patterns, standards)
         - Artifacts (files, classes, modules)
         - Organizations (teams, companies)

      2. **Facts**: Relationships or attributes about entities
         - Relationships between entities: "X depends on Y", "A owns B"
         - Attributes: "X has version 2.0", "Y has status active"

      Rules:
      - Prefer matching existing entities over creating new ones
      - Use clear, canonical names for new entities
      - Assign confidence scores (0.0-1.0) based on certainty
      - Only include facts that are clearly stated or strongly implied
    PROMPT

    def preconditions_met?
      Rails.application.config.llm.enabled && should_use_llm?
    end

    def perform_work
      input = task.result_for(ValidateInput)
      card = task.card

      existing_entities_text = input[:existing_entities].first(30).map do |e|
        "- #{e.name} (#{e.entity_type})"
      end.join("\n")

      existing_domains_text = input[:board].domains.pluck(:name).join(", ")

      prompt = format(
        EXTRACTION_PROMPT,
        title: card.title,
        description: card.description || "(no description)",
        existing_entities: existing_entities_text.presence || "(none)",
        existing_domains: existing_domains_text.presence || "General"
      )

      response = Llm::Router.route(:knowledge_extraction, prompt)

      if response.success?
        task.broadcast_stage_progress(KnowledgeExtractionTask::STAGE_PERSISTING)
        parsed = parse_response(response)
        Success(
          entities: parsed[:entities],
          facts: parsed[:facts],
          provider: response.provider,
          stage: name
        )
      else
        # LLM failure is non-critical
        Success(entities: [], facts: [], error: response.error, stage: name)
      end
    end

    private

    def should_use_llm?
      card = task.card
      return false unless card

      pattern_result = task.result_for(PatternExtract)
      pattern_count = (pattern_result[:entities]&.count || 0) + (pattern_result[:facts]&.count || 0)

      content_length = (card.title&.length || 0) + (card.description&.length || 0)
      content_length > 50 && pattern_count < 3
    end

    def parse_response(response)
      validation = response.validated_json(:knowledge_extraction)

      data = if validation.valid?
        validation.data
      else
        response.parsed_json || {}
      end

      entities = (data["entities"] || []).map do |e|
        {
          name: e["name"],
          entity_type: e["entity_type"],
          description: e["description"],
          confidence: e["confidence"] || 0.8,
          is_new: e["is_new"],
          existing_name: e["existing_entity_name"],
          extraction_method: "ai_llm"
        }
      end

      facts = (data["facts"] || []).map do |f|
        {
          subject_name: f["subject"],
          predicate: f["predicate"],
          object_name: f["object"],
          object_is_entity: f["object_is_entity"],
          object_type: f["object_type"],
          confidence: f["confidence"] || 0.8,
          negated: f["negated"] || false,
          extraction_method: "ai_llm"
        }
      end

      { entities: entities, facts: facts }
    end
  end

  # Stage 5: Persist results
  class PersistResults < TaskFrame::Stage
    include Dry::Monads[:result]

    def perform_work
      input = task.result_for(ValidateInput)
      pattern_result = task.result_for(PatternExtract)
      link_result = task.result_for(LinkEntities)
      llm_result = task.result_for(LlmExtract)

      card = task.card
      default_domain = input[:default_domain]

      # Combine all extracted data
      all_entities = (pattern_result[:entities] || []) + (llm_result&.dig(:entities) || [])
      all_facts = (pattern_result[:facts] || []) + (llm_result&.dig(:facts) || [])
      all_mentions = link_result[:mentions] || []

      persisted = { entities: [], facts: [], mentions: [] }

      ActiveRecord::Base.transaction do
        # Persist entities
        all_entities.each do |entity_data|
          entity = persist_entity(entity_data, default_domain)
          persisted[:entities] << entity if entity
        end

        # Persist facts
        all_facts.each do |fact_data|
          fact = persist_fact(fact_data, card, default_domain)
          persisted[:facts] << fact if fact
        end

        # Persist mentions
        all_mentions.each do |mention_data|
          mention = persist_mention(mention_data, card)
          persisted[:mentions] << mention if mention
        end
      end

      task.broadcast_stage_progress(KnowledgeExtractionTask::STAGE_COMPLETE)

      Success(
        entities: persisted[:entities],
        facts: persisted[:facts],
        mentions: persisted[:mentions],
        counts: {
          entities: persisted[:entities].count,
          facts: persisted[:facts].count,
          mentions: persisted[:mentions].count
        },
        stage: name
      )
    end

    private

    def persist_entity(data, default_domain)
      return nil if data[:name].blank?

      entity = default_domain.entities.find_or_initialize_by(name: data[:name])

      if entity.new_record?
        entity.entity_type = data[:entity_type] || infer_entity_type(data[:name])
        entity.description = data[:description]
        entity.confidence = data[:confidence] || 0.8
        entity.save!
        entity
      else
        nil # Already exists
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def persist_fact(data, card, default_domain)
      subject = find_or_create_entity(data[:subject_name], default_domain)
      return nil unless subject

      object_entity = nil
      object_value = nil

      if data[:object_is_entity]
        object_entity = find_or_create_entity(data[:object_name], default_domain)
      else
        object_value = data[:object_name]
      end

      return nil if object_entity.nil? && object_value.nil?

      fact = Fact.find_or_initialize_by(
        subject_entity: subject,
        predicate: data[:predicate],
        object_entity: object_entity,
        object_value: object_value,
        domain: default_domain
      )

      if fact.new_record?
        fact.confidence = data[:confidence] || 0.8
        fact.extraction_method = data[:extraction_method] || "ai_llm"
        fact.negated = data[:negated] || false
        fact.object_type = data[:object_type] unless data[:object_is_entity]
        fact.save!

        # Link to card
        CardFact.create!(card: card, fact: fact, role: "source", source_field: "description")

        fact
      else
        nil
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def persist_mention(data, card)
      entity = Entity.find_by(id: data[:entity_id])
      return nil unless entity

      mention = EntityMention.find_or_initialize_by(
        entity: entity,
        card: card,
        mention_text: data[:mention_text],
        source_field: data[:source_field]
      )

      if mention.new_record?
        mention.text_offset_start = data[:offset_start]
        mention.text_offset_end = data[:offset_end]
        mention.confidence = data[:confidence] || 0.8
        mention.extraction_method = data[:extraction_method] || "fuzzy_match"
        mention.save!
        mention
      else
        nil
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def find_or_create_entity(name, domain)
      return nil if name.blank?

      domain.entities.find_by(name: name) ||
        domain.entities.named(name).first ||
        domain.entities.create!(
          name: name,
          entity_type: infer_entity_type(name),
          confidence: 0.7
        )
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def infer_entity_type(name)
      return "person" if name.match?(/^[A-Z][a-z]+ [A-Z][a-z]+$/)
      return "system" if name.match?(/service|api|server|database/i)
      return "artifact" if name.match?(/controller|model|component|module/i)

      "concept"
    end
  end

  # Stage 6: Broadcast completion
  class Broadcast < TaskFrame::Stage
    def perform_work
      card = task.card
      result = task.result_for(PersistResults)

      broadcast_replace(
        stream: "card_#{card.id}_knowledge",
        target: "card-#{card.id}-knowledge-extraction",
        partial: "cards/knowledge_extraction_complete",
        locals: {
          card: card,
          entities: result[:entities],
          facts: result[:facts],
          mentions: result[:mentions],
          counts: result[:counts]
        }
      )

      Success(
        broadcast: true,
        card_id: card.id,
        counts: result[:counts],
        stage: name
      )
    end

    private

    def broadcast_replace(stream:, target:, partial:, locals:)
      task.broadcast_replace(
        stream: stream,
        target: target,
        partial: partial,
        locals: locals
      )
    end
  end
end
