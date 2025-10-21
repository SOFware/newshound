Dir[File.join(__dir__, "exceptions", "*.rb")].each { |file| require file }

module Newshound
  module Exceptions
    def self.source(source)
      constant = constants.find { |c| c.to_s.gsub(/(?<!^)([A-Z])/, "_\\1").downcase == source.to_s }
      raise "Invalid exception source: #{source}" unless constant

      const_get(constant).new
    end
  end
end
