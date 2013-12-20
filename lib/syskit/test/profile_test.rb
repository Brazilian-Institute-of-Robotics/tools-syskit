module Syskit
    module Test
        # Base class for testing {Actions::Profile}
        class ProfileTest < Spec
            include Syskit::Test
            include ProfileAssertions
            extend ProfileModelAssertions

            def assert_is_self_contained(definition, message = "#{definition.name}_def is not self contained")
                engine, _ = self.class.try_instanciate(__full_name__, plan, [definition],
                                           :compute_policies => false,
                                           :compute_deployments => false,
                                           :validate_generated_network => false)
                still_abstract = plan.find_local_tasks(Syskit::Component).
                    abstract.to_a
                still_abstract.delete_if { |task| task.class <= Actions::Profile::Tag }
                if !still_abstract.empty?
                    raise Assertion.new(TaskAllocationFailed.new(engine, still_abstract)), message
                end
            end

            # Tests that the only variation points left in all definitions are
            # profile tags
            def self.it_should_be_self_contained(*definitions)
                if definitions.empty?
                    definitions = desc.definitions.values
                end
                definitions.each do |d|
                    it "#{d.name}_def should be self-contained" do
                        assert_is_self_contained(d)
                    end
                end
            end

            def self.method_missing(m, *args)
                MetaRuby::DSLs.find_through_method_missing(desc, m, args, 'def' => 'definition') ||
                    super
            end
        end
    end
end