# frozen_string_literal: true

module EntityKnowledge
  module Extraction
    class EntityLinker
      # Links text mentions to known entities using fuzzy matching.
      # This enables entity resolution and coreference.
      #
      # Usage:
      #   linker = EntityKnowledge::Extraction::EntityLinker.new
      #   entities = [{ id: 1, name: "John Smith", aliases: ["John", "JS"] }]
      #   result = linker.link("Fixed by John", entities)
      #   # => { mentions: [...] }

      DEFAULT_FUZZY_THRESHOLD = 0.8
      DEFAULT_MIN_TOKEN_LENGTH = 3

      COMMON_WORDS = %w[
        The This That These Those Which Where When What How
        For From With Into About After Before During Without
        Should Would Could Must Have Been Being Done Made
        Card Task Bug Issue Sprint Release Feature Update
      ].freeze

      def initialize(fuzzy_threshold: nil, min_token_length: nil)
        @fuzzy_threshold = fuzzy_threshold || EntityKnowledge.configuration.fuzzy_threshold
        @min_token_length = min_token_length || EntityKnowledge.configuration.min_token_length
      end

      def link(text, entities, source_field: "content")
        return { mentions: [] } if text.blank? || entities.empty?

        mentions = []
        entity_index = build_entity_index(entities)
        tokens = extract_tokens(text)

        tokens.each do |token_info|
          match = find_best_match(token_info[:token], entity_index)
          next unless match

          mentions << {
            entity_id: match[:entity_id],
            mention_text: token_info[:token],
            source_field: source_field,
            offset_start: token_info[:start],
            offset_end: token_info[:end],
            confidence: match[:confidence],
            extraction_method: match[:method]
          }
        end

        { mentions: deduplicate_mentions(mentions) }
      end

      private

      def build_entity_index(entities)
        index = { exact: {}, aliases: {}, tokens: {} }

        entities.each do |entity|
          entity_id = entity[:id] || entity["id"]
          name = entity[:name] || entity["name"]
          aliases = entity[:aliases] || entity["aliases"] || []

          # Exact name match
          index[:exact][name.downcase] = entity_id

          # Alias matches
          aliases.each do |alias_name|
            index[:aliases][alias_name.downcase] = entity_id
          end

          # Token-based index for fuzzy matching
          tokenize_name(name).each do |token|
            index[:tokens][token.downcase] ||= []
            index[:tokens][token.downcase] << { entity_id: entity_id, full_name: name }
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
        return nil if token.length < @min_token_length

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
            match = matches.first
            return { entity_id: match[:entity_id], confidence: 0.75, method: "token_overlap" }
          end
        end

        nil
      end

      def similarity(str1, str2)
        return 1.0 if str1 == str2
        return 0.0 if str1.empty? || str2.empty?

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
              d[i - 1][j] + 1,
              d[i][j - 1] + 1,
              d[i - 1][j - 1] + cost
            ].min
          end
        end

        d[m][n]
      end

      def tokenize_name(name)
        name.split(/[\s_]|(?=[A-Z])/).reject(&:empty?)
      end

      def common_word?(word)
        COMMON_WORDS.include?(word)
      end

      def deduplicate_mentions(mentions)
        mentions
          .group_by { |m| [m[:entity_id], m[:offset_start]] }
          .values
          .map { |group| group.max_by { |m| m[:confidence] } }
      end
    end
  end
end
