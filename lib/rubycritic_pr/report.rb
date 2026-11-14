# frozen_string_literal: true

require 'json'

module RubycriticPr
  # A parsed RubyCritic `report.json`.
  class Report
    class MissingReport < StandardError; end

    Smell = Struct.new(:context, :message, :score, :type, :locations, keyword_init: true) do
      # Same identity RubyCritic uses (Smell#state). Locations are left out on
      # purpose so code that only moved is not reported as new.
      def key
        [context, message, score, type]
      end
    end

    attr_reader :score, :smells

    def self.load(path)
      raise MissingReport, "RubyCritic report not found: #{path}" unless File.file?(path)

      from_hash(JSON.parse(File.read(path)))
    end

    # Reports live at <root>/compare/<branch>/report.json. Branch names with a
    # slash nest, so fall back to a glob if the exact path is not there.
    def self.find(root, branch)
      exact = File.join(root, 'compare', branch, 'report.json')
      return exact if File.file?(exact)

      Dir.glob(File.join(root, '**', branch, 'report.json')).first || exact
    end

    def self.from_hash(data)
      smells = Array(data['analysed_modules']).flat_map do |mod|
        Array(mod['smells']).map do |s|
          Smell.new(
            context: s['context'], message: s['message'], score: s['score'], type: s['type'],
            locations: Array(s['locations']).map { |l| { path: l['path'], line: l['line'] } }
          )
        end
      end
      new(score: data['score'].to_f, smells: smells)
    end

    # A smell with several locations (duplication) is listed under every
    # module it touches, so collapse identical copies.
    def initialize(score:, smells:)
      @score = score
      @smells = smells.uniq { |s| [s.key, s.locations] }
    end
  end
end
