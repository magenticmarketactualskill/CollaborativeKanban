# frozen_string_literal: true

module CardIntelligence
  class EntityLinker
    # Links text mentions to known entities using fuzzy matching.
    # This enables entity resolution and coreference.
    #
    # Matching strategies:
    # 1. Exact match (case-insensitive)
    # 2. Alias match
    # 3. Fuzzy match (Levenshtein distance)
    # 4. Token overlap match

    FUZZY_THRESHOLD = 0.8  # Minimum similarity score
    MIN_TOKEN_LENGTH = 3   # Minimum characters to consider for matching

    def initialize(fuzzy_threshold: FUZZY_THRESHOLD)
      @fuzzy_threshold = fuzzy_threshold
    end

    def link(card, entities)
      mentions = []
      entity_index = build_entity_index(entities)

      text_fields = [
        { field: "title", text: card.title },
        { field: "description", text: card.description }
      ].compact_blank

      text_fields.each do |field_info|
        field = field_info[:field]
        text = field_info[:text]
        next if text.blank?

        # Tokenize and find potential matches
        tokens = extract_tokens(text)

        tokens.each do |token_info|
          match = find_best_match(token_info[:token], entity_index)
          next unless match

          mentions << {
            entity_id: match[:entity_id],
            mention_text: token_info[:token],
            source_field: field,
            offset_start: token_info[:start],
            offset_end: token_info[:end],
            confidence: match[:confidence],
            extraction_method: match[:method]
          }
        end
      end

      { mentions: deduplicate_mentions(mentions) }
    end

    private

    def build_entity_index(entities)
      index = { exact: {}, aliases: {}, tokens: {} }

      entities.each do |entity|
        # Exact name match
        index[:exact][entity.name.downcase] = entity.id

        # Alias matches
        (entity.aliases || []).each do |alias_name|
          index[:aliases][alias_name.downcase] = entity.id
        end

        # Token-based index for fuzzy matching
        tokenize_name(entity.name).each do |token|
          index[:tokens][token.downcase] ||= []
          index[:tokens][token.downcase] << { entity_id: entity.id, full_name: entity.name }
        end
      end

      index
    end

    def extract_tokens(text)
      tokens = []

      # Multi-word tokens (2-4 words)
      text.scan(/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})\b/) do |match|
        word = match[0]
        start_pos = Regexp.last_match.begin(0)
        tokens << { token: word, start: start_pos, end: start_pos + word.length }
      end

      # Single capitalized words (potential names)
      text.scan(/\b([A-Z][a-z]{2,})\b/) do |match|
        word = match[0]
        start_pos = Regexp.last_match.begin(0)
        # Skip common words
        next if common_word?(word)

        tokens << { token: word, start: start_pos, end: start_pos + word.length }
      end

      # Technical terms (CamelCase, snake_case)
      text.scan(/\b([A-Z][a-z]+(?:[A-Z][a-z]+)+|[a-z]+(?:_[a-z]+)+)\b/) do |match|
        word = match[0]
        start_pos = Regexp.last_match.begin(0)
        tokens << { token: word, start: start_pos, end: start_pos + word.length }
      end

      tokens.uniq { |t| [t[:start], t[:end]] }
    end

    def find_best_match(token, index)
      return nil if token.length < MIN_TOKEN_LENGTH

      normalized = token.downcase

      # Strategy 1: Exact match
      if (entity_id = index[:exact][normalized])
        return { entity_id: entity_id, confidence: 1.0, method: "exact_match" }
      end

      # Strategy 2: Alias match
      if (entity_id = index[:aliases][normalized])
        return { entity_id: entity_id, confidence: 0.95, method: "alias_match" }
      end

      # Strategy 3: Fuzzy match
      best_fuzzy = nil
      best_score = @fuzzy_threshold

      index[:exact].each do |name, entity_id|
        score = similarity(normalized, name)
        if score > best_score
          best_score = score
          best_fuzzy = { entity_id: entity_id, confidence: score, method: "fuzzy_match" }
        end
      end

      return best_fuzzy if best_fuzzy

      # Strategy 4: Token overlap
      token_parts = tokenize_name(token)
      token_parts.each do |part|
        if (matches = index[:tokens][part.downcase])
          # Return the first match with medium confidence
          match = matches.first
          return { entity_id: match[:entity_id], confidence: 0.75, method: "token_overlap" }
        end
      end

      nil
    end

    def similarity(str1, str2)
      # Jaro-Winkler similarity (approximation)
      return 1.0 if str1 == str2
      return 0.0 if str1.empty? || str2.empty?

      # Simple Levenshtein-based similarity
      max_len = [str1.length, str2.length].max
      distance = levenshtein_distance(str1, str2)
      1.0 - (distance.to_f / max_len)
    end

    def levenshtein_distance(str1, str2)
      m = str1.length
      n = str2.length

      return n if m.zero?
      return m if n.zero?

      d = Array.new(m + 1) { Array.new(n + 1, 0) }

      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      (1..m).each do |i|
        (1..n).each do |j|
          cost = str1[i - 1] == str2[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      d[m][n]
    end

    def tokenize_name(name)
      # Split on spaces, underscores, and CamelCase boundaries
      name.split(/[\s_]|(?=[A-Z])/).reject(&:empty?)
    end

    def common_word?(word)
      %w[
        The This That These Those Which Where When What How
        For From With Into About After Before During Without
        Should Would Could Must Have Been Being Done Made
        Card Task Bug Issue Sprint Release Feature Update
      ].include?(word)
    end

    def deduplicate_mentions(mentions)
      # Keep highest confidence mention for each entity-position combo
      mentions
        .group_by { |m| [m[:entity_id], m[:offset_start]] }
        .values
        .map { |group| group.max_by { |m| m[:confidence] } }
    end
  end
end
