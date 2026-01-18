# frozen_string_literal: true

module CardIntelligence
  class KnowledgeExtractor
    # Hybrid extraction service that combines:
    # 1. Pattern-based extraction (fast, high precision)
    # 2. LLM-based extraction (slower, handles nuance)
    # 3. Entity linking (matches mentions to known entities)
    #
    # Usage:
    #   extractor = CardIntelligence::KnowledgeExtractor.new
    #   result = extractor.extract(card)
    #
    # Returns ExtractionResult with entities, facts, and mentions

    ExtractionResult = Struct.new(
      :entities, :facts, :mentions, :errors, :extraction_stats,
      keyword_init: true
    ) do
      def success?
        errors.empty?
      end

      def total_extracted
        entities.count + facts.count + mentions.count
      end
    end

    def initialize(llm_router: nil)
      @llm_router = llm_router || Llm::Router.new
      @pattern_extractor = PatternExtractor.new
      @entity_linker = EntityLinker.new
    end

    def extract(card)
      board = card.board
      ensure_default_domain(board)

      entities = []
      facts = []
      mentions = []
      errors = []
      stats = { pattern: 0, llm: 0, linked: 0 }

      # Phase 1: Pattern-based extraction (fast)
      begin
        pattern_result = @pattern_extractor.extract(card)
        entities.concat(pattern_result[:entities])
        facts.concat(pattern_result[:facts])
        stats[:pattern] = pattern_result[:entities].count + pattern_result[:facts].count
      rescue StandardError => e
        errors << "Pattern extraction failed: #{e.message}"
      end

      # Phase 2: Entity linking (match text to existing entities)
      begin
        link_result = @entity_linker.link(card, board.entities)
        mentions.concat(link_result[:mentions])
        stats[:linked] = link_result[:mentions].count
      rescue StandardError => e
        errors << "Entity linking failed: #{e.message}"
      end

      # Phase 3: LLM extraction (if enabled and worthwhile)
      if should_use_llm?(card, stats)
        begin
          llm_result = extract_with_llm(card, board)
          entities.concat(llm_result[:entities])
          facts.concat(llm_result[:facts])
          stats[:llm] = llm_result[:entities].count + llm_result[:facts].count
        rescue StandardError => e
          errors << "LLM extraction failed: #{e.message}"
        end
      end

      # Phase 4: Persist results
      persisted = persist_results(card, entities: entities, facts: facts, mentions: mentions)

      ExtractionResult.new(
        entities: persisted[:entities],
        facts: persisted[:facts],
        mentions: persisted[:mentions],
        errors: errors,
        extraction_stats: stats
      )
    end

    private

    def ensure_default_domain(board)
      return if board.domains.exists?

      board.domains.create!(
        name: "General",
        description: "Auto-created domain for extracted knowledge",
        system_generated: true,
        color: "#6B7280"
      )
    end

    def should_use_llm?(card, stats)
      return false unless Rails.application.config.llm.enabled

      # Use LLM if:
      # 1. Card has substantial content
      # 2. Pattern extraction found little
      content_length = (card.title&.length || 0) + (card.description&.length || 0)
      content_length > 50 && stats[:pattern] < 3
    end

    def extract_with_llm(card, board)
      existing_entities = board.entities.limit(50).pluck(:name, :entity_type)
      existing_domains = board.domains.pluck(:name)

      prompt = build_extraction_prompt(card, existing_entities, existing_domains)
      response = @llm_router.chat(
        messages: [{ role: "user", content: prompt }],
        response_schema: extraction_schema
      )

      parse_llm_response(response, board)
    end

    def build_extraction_prompt(card, existing_entities, existing_domains)
      <<~PROMPT
        Extract entities and facts from this card content.

        Card Title: #{card.title}
        Card Description: #{card.description || "(none)"}

        Existing entities in this board (reuse if mentioned):
        #{existing_entities.map { |name, type| "- #{name} (#{type})" }.join("\n")}

        Existing domains: #{existing_domains.join(", ")}

        Extract:
        1. Entities: Named things (people, systems, concepts, etc.)
        2. Facts: Relationships between entities or entity attributes

        Rules:
        - Prefer linking to existing entities over creating new ones
        - Use clear, canonical names for new entities
        - Facts should be specific and verifiable
        - Include confidence scores (0.0-1.0)
      PROMPT
    end

    def extraction_schema
      {
        type: "object",
        properties: {
          entities: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                entity_type: { type: "string", enum: Entity::ENTITY_TYPES },
                description: { type: "string" },
                confidence: { type: "number", minimum: 0, maximum: 1 },
                is_new: { type: "boolean" }
              },
              required: %w[name entity_type confidence is_new]
            }
          },
          facts: {
            type: "array",
            items: {
              type: "object",
              properties: {
                subject: { type: "string" },
                predicate: { type: "string" },
                object: { type: "string" },
                object_is_entity: { type: "boolean" },
                confidence: { type: "number", minimum: 0, maximum: 1 }
              },
              required: %w[subject predicate object object_is_entity confidence]
            }
          }
        },
        required: %w[entities facts]
      }
    end

    def parse_llm_response(response, board)
      data = response[:content]
      default_domain = board.domains.first

      entities = (data["entities"] || []).map do |e|
        {
          name: e["name"],
          entity_type: e["entity_type"],
          description: e["description"],
          confidence: e["confidence"],
          domain: default_domain,
          extraction_method: "ai_llm"
        }
      end

      facts = (data["facts"] || []).map do |f|
        {
          subject_name: f["subject"],
          predicate: f["predicate"],
          object_name: f["object"],
          object_is_entity: f["object_is_entity"],
          confidence: f["confidence"],
          domain: default_domain,
          extraction_method: "ai_llm"
        }
      end

      { entities: entities, facts: facts }
    end

    def persist_results(card, entities:, facts:, mentions:)
      board = card.board
      default_domain = board.domains.first

      persisted_entities = []
      persisted_facts = []
      persisted_mentions = []

      ActiveRecord::Base.transaction do
        # Persist entities
        entities.each do |entity_data|
          domain = entity_data[:domain] || default_domain
          entity = domain.entities.find_or_initialize_by(name: entity_data[:name])

          if entity.new_record?
            entity.assign_attributes(
              entity_type: entity_data[:entity_type],
              description: entity_data[:description],
              confidence: entity_data[:confidence] || 0.8
            )
            entity.save!
            persisted_entities << entity
          end
        end

        # Persist facts
        facts.each do |fact_data|
          domain = fact_data[:domain] || default_domain
          subject = find_or_create_entity(fact_data[:subject_name], domain)
          next unless subject

          object_entity = nil
          object_value = nil

          if fact_data[:object_is_entity]
            object_entity = find_or_create_entity(fact_data[:object_name], domain)
          else
            object_value = fact_data[:object_name]
          end

          fact = Fact.find_or_initialize_by(
            subject_entity: subject,
            predicate: fact_data[:predicate],
            object_entity: object_entity,
            object_value: object_value,
            domain: domain
          )

          if fact.new_record?
            fact.confidence = fact_data[:confidence] || 0.8
            fact.extraction_method = fact_data[:extraction_method] || "ai_llm"
            fact.save!
            persisted_facts << fact

            # Link fact to card
            CardFact.create!(
              card: card,
              fact: fact,
              role: "source",
              source_field: "description"
            )
          end
        end

        # Persist mentions
        mentions.each do |mention_data|
          entity = Entity.find_by(id: mention_data[:entity_id])
          next unless entity

          mention = EntityMention.find_or_initialize_by(
            entity: entity,
            card: card,
            mention_text: mention_data[:mention_text],
            source_field: mention_data[:source_field]
          )

          if mention.new_record?
            mention.assign_attributes(
              text_offset_start: mention_data[:offset_start],
              text_offset_end: mention_data[:offset_end],
              confidence: mention_data[:confidence] || 0.8,
              extraction_method: mention_data[:extraction_method] || "fuzzy_match"
            )
            mention.save!
            persisted_mentions << mention
          end
        end
      end

      {
        entities: persisted_entities,
        facts: persisted_facts,
        mentions: persisted_mentions
      }
    end

    def find_or_create_entity(name, domain)
      return nil if name.blank?

      # Try exact match first
      entity = domain.entities.find_by(name: name)
      return entity if entity

      # Try alias match
      entity = domain.entities.named(name).first
      return entity if entity

      # Create new entity with inferred type
      domain.entities.create!(
        name: name,
        entity_type: infer_entity_type(name),
        confidence: 0.7
      )
    end

    def infer_entity_type(name)
      # Simple heuristics for entity type inference
      return "person" if name.match?(/^[A-Z][a-z]+ [A-Z][a-z]+$/) # "John Smith"
      return "system" if name.match?(/service|api|server|database/i)
      return "artifact" if name.match?(/controller|model|component|module/i)
      return "event" if name.match?(/sprint|release|meeting|review/i)

      "concept"
    end
  end
end
