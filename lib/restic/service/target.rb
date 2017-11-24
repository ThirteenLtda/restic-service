module Restic
    module Service
        class Target
            attr_reader :name
            attr_reader :host
            attr_accessor :keys

            def initialize(name, host)
                @name = name
                @host = host
                @keys = Array.new
            end

            def valid?(actual_keys)
                actual_keys.any? { |k| keys.include?(k) }
            end
        end
    end
end

