# frozen_string_literal: true

module RubycriticPr
  # Works out which smells the head report has that the base report did not.
  module SmellDiff
    # kind is :new or :worse. previous_message is set for :worse.
    Finding = Struct.new(:smell, :kind, :previous_message, keyword_init: true)

    module_function

    def call(base_smells, head_smells)
      remaining = base_smells.group_by(&:key)
      unmatched = []

      head_smells.each do |smell|
        bucket = remaining[smell.key]
        if bucket && !bucket.empty?
          bucket.shift
        else
          unmatched << smell
        end
      end

      leftovers = remaining.values.flatten
      unmatched.map do |smell|
        previous = leftovers.find { |b| b.type == smell.type && b.context == smell.context }
        leftovers.delete(previous) if previous
        Finding.new(smell: smell, kind: previous ? :worse : :new, previous_message: previous&.message)
      end
    end
  end
end
