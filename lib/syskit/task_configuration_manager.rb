module Syskit
    # Adapter for {Orocos::TaskConfigurations} to take into account the
    # conventions inside Syskit apps
    class TaskConfigurationManager < Orocos::TaskConfigurations
        attr_reader :app
        attr_reader :syskit_model

        def orogen_model; syskit_model.orogen_model end

        def initialize(app, syskit_model)
            @app = app
            @syskit_model = syskit_model
            super(orogen_model)
        end

        # Extract the configuration from a running task
        def extract_from_task
        end

        # Applies a configuration to the given component instance
        #
        # @param [TaskContext] syskit_task the task instance on which the
        #   configuration should be applied
        # @param [String,Array<String>] conf a list of configuration sections.
        #   It defaults to the {syskit_task.conf}
        # @param [Boolean] override if true, the various selected sections can
        #   override each other. Otherwise, that would generate an error
        # @return [void]
        def apply(syskit_task, conf: syskit_task.conf, override: false)
            super(syskit_task.orocos_task, conf, override)
        end

        # Returns the path to an existing configuration file
        #
        # @param [Boolean] local_only whether the search should restrict itself
        #   to the current Roby app or should include the inherited apps as well
        # @return [String,nil] the path found or nil if no file was found
        def existing_configuration_file(local_only: false)
            local_option = Hash.new
            if local_only
                local_option[:path] = [app.app_dir]
            end
            app.find_file('config', 'orogen', 'ROBOT', "#{orogen_model.name}.yml",
                          order: :specific_first, all: false, **local_option)
        end

        # Tests whether there is a configuration file for this model
        def has_configuration_file?(local_only: false)
            !!existing_configuration_file(local_only: local_only)
        end

        # Save a configuration section to file
        #
        # Note that it does NOT extract the configuration from the running
        # task(s), it only saves the state of the configuration as currently
        # stored in the manager
        #
        # @param [String] section_name the section that should be saved
        # @param [String] file the file to save into. It defaults to saving at
        #   the standard location in this Roby app
        # @param [Boolean] replace if true, existing sections that have been
        #   changed (and all their custom comments) will be removed by the
        #   operation. If false, the new sections are appended (which also means
        #   that duplicate sections will exist in the file)
        # @return [void]
        def save(section_name, file: nil, replace: false)
            path = file ||
                existing_configuration_file(local_only: true) ||
                File.join(Roby.app_dir, 'config', 'orogen', "#{orogen_model.name}.yml")
            super(section_name, path, replace: replace)
        end

        # Loads or reload the configuration for this task from disk
        #
        # @return [Array<String>] a list of configuration sections that have
        #   been modified
        def reload
            if conf_file = existing_configuration_file
                app.isolate_load_errors("could not load oroGen configuration file #{conf_file}") do
                    load_from_yaml(conf_file)
                end
            else
                Array.new
            end
        end
    end
end

