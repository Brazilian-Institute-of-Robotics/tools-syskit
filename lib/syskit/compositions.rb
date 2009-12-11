module Orocos
    module RobyPlugin
        class CompositionChild
            attr_reader :composition, :name, :child
            def initialize(composition, name, child)
                @composition = composition
                @name = name
                @child = child
            end

            def method_missing(name, *args)
                if args.empty? && (port = child.port(name))
                    CompositionChildPort.new(self, port)
                else
                    raise NoMethodError, "#{child} has no port named #{name}", caller(1)
                end
            end

            def ==(other)
                other.composition == composition &&
                    other.name == name
            end
        end
        class CompositionChildPort
            attr_reader :child, :port
            def name
                port.name
            end
            def initialize(child, port)
                @child = child
                @port  = port
            end

            def ==(other)
                other.child == child &&
                    other.port == port
            end
        end

        module CompositionModel
            include Model

            attr_accessor :name

            def new_submodel(name, system)
                klass = super()
                klass.name = name
                klass.system = system
                klass
            end

            attribute(:children) { Hash.new }

            def [](name)
                children[name]
            end
            def add_child(name, task)
                children[name.to_s] = task
            end

            def add(model_name, options = Hash.new)
                options = Kernel.validate_options options, :as => model_name
                task = system.get(model_name)

                add_child(options[:as], task)
                CompositionChild.new(self, options[:as], task)
            end

            # The set of connections specified by the user for this composition
            attribute(:explicit_connections) { Hash.new { |h, k| h[k] = Hash.new } }
            # The set of connections automatically generated by
            # compute_autoconnection
            attribute(:automatic_connections) { Hash.new { |h, k| h[k] = Hash.new } }

            # Outputs exported from this composition
            attribute(:outputs)  { Hash.new }
            # Inputs imported from this composition
            attribute(:inputs)   { Hash.new }

            def autoconnect(*names)
                @autoconnect = if names.empty? 
                                   children.keys
                               else
                                   names
                               end
            end

            def compute_autoconnection
                if @autoconnect && !@autoconnect.empty?
                    do_autoconnect(@autoconnect)
                end
            end

            # Automatically compute the connections that can be done in the
            # limits of this composition, and returns the set.
            #
            # Connections are determined by port direction and type name.
            #
            # It raises AmbiguousConnections if autoconnection does not know
            # what to do.
            def do_autoconnect(children_names)
                result = Hash.new { |h, k| h[k] = Hash.new }
                child_inputs  = Hash.new { |h, k| h[k] = Array.new }
                child_outputs = Hash.new { |h, k| h[k] = Array.new }

                # Gather all child input and outputs
                children_names.each do |name|
                    sys = children[name]
                    sys.each_input do |in_port|
                        if !exported_port?(in_port)
                            child_inputs[in_port.type_name] << [name, in_port.name]
                        end
                    end

                    sys.each_output do |out_port|
                        if !exported_port?(out_port)
                            child_outputs[out_port.type_name] << [name, out_port.name]
                        end
                    end
                end

                # Make sure there is only one input for one output, and add the
                # connections
                child_inputs.each do |typename, in_ports|
                    in_ports.each do |in_child_name, in_port_name|
                        out_ports = child_outputs[typename]
                        out_ports.delete_if do |out_child_name, out_port_name|
                            out_child_name == in_child_name
                        end
                        next if out_ports.empty?

                        if out_ports.size > 1
                            # Check for port name
                            same_name = out_ports.find_all { |_, out_port_name| out_port_name == in_port_name }
                            if same_name.size == 1
                                out_ports = same_name
                            end
                        end

                        if out_ports.size > 1
                            out_port_names = out_ports.map { |child_name, port_name| "#{child_name}.#{port_name}" }
                            raise Ambiguous, "multiple output candidates in #{name} for #{in_child_name}.#{in_port_name} (of type #{typename}): #{out_port_names.join(", ")}"
                        end

                        out_port = out_ports.first
                        result[[out_port[0], in_child_name]][ [out_port[1], in_port_name] ] = Hash.new
                    end
                end

                self.automatic_connections = result
            end

            def connections
                automatic_connections.merge(explicit_connections) do |key, old, new|
                    old.merge(new)
                end
            end

            def export(port, options = Hash.new)
                options = Kernel.validate_options options, :as => port.name
                name = options[:as].to_str
                if self.port(name)
                    raise SpecError, "there is already a port named #{name} on #{self}"
                end

                case port.port
                when Generation::OutputPort
                    outputs[name] = port
                when Generation::InputPort
                    inputs[name] = port
                else
                    raise TypeError, "invalid port #{port} of type #{port.class}"
                end
            end

            def port(name)
                name = name.to_str
                outputs[name] || inputs[name]
            end

            def exported_port?(port_model)
                outputs.values.any? { |p| port_model == p } ||
                    inputs.values.any? { |p| port_model == p }
            end

            def each_output(&block)
                if !@exported_outputs
                    @exported_outputs = outputs.map do |name, p|
                        p.class.new(self, name, p.type_name, p.port_model)
                    end
                end
                @exported_outputs.each(&block)
            end
            def each_input(&block)
                if !@exported_inputs
                    @exported_inputs = inputs.map do |name, p|
                        p.class.new(self, name, p.type_name, p.port_model)
                    end
                end
                @exported_inputs.each(&block)
            end

            def connect(mappings)
                options = Hash.new
                mappings.delete_if do |a, b|
                    if a.respond_to?(:to_str)
                        options[a] = b
                    end
                end
                options = Kernel.validate_options options, Orocos::Port::CONNECTION_POLICY_OPTIONS
                mappings.each do |out_p, in_p|
                    explicit_connections[[out_p.child.name, in_p.child.name]][ [out_p.port.name, in_p.port.name] ] = options
                end
            end

            def apply_port_mappings(connections, child_name, port_mappings)
                connections.each do |(out_name, in_name), mappings|
                    mapped_connections = Hash.new

                    if out_name == child_name
                        mappings.delete_if do |(out_port, in_port), options|
                            if mapped_port = port_mappings[out_port]
                                mapped_connections[ [in_port, mapped_port] ] = options
                            end
                        end

                    elsif in_name == child_name
                        mappings.delete_if do |(out_port, in_port), options|
                            if mapped_port = port_mappings[in_port]
                                mapped_connections[ [mapped_port, out_port] ] = options
                            end
                        end
                    end
                    mappings.merge!(mapped_connections)
                end
                connections
            end

            def instanciate(engine, arguments = Hash.new)
                arguments, task_arguments = Model.filter_instanciation_arguments(arguments)
                selection = arguments[:selection]

                engine.plan.add(self_task = new(task_arguments))

                children_tasks = Hash.new
                children.each do |child_name, child_model|
                    role = if child_name == child_model.name
                               Set.new
                           else [child_name].to_set
                           end

                    # The model this composition actually requires. It may be
                    # different than child_model in case of explicit selection
                    dependent_model = child_model

                    # Check if an explicit selection applies
                    selected_object = (selection[child_model.name] || selection[child_name])
                    if selected_object
                        if selected_object.respond_to?(:to_str)
                            selected_object_name = selected_object.to_str
                            if !(selected_object = engine.apply_selection(selected_object_name))
                                raise SpecError, "#{selected_object_name} is not a task model name, not a device type nor a device name"
                            end
                        end

                        # Check that the selection is actually valid
                        if !selected_object.fullfills?(child_model)
                            raise SpecError, "cannot select #{selected_object} for #{child_model}: #{selected_object} is not a specialized model for #{child_model}"
                        end

                        # +selected_object+ can either be a task instance
                        # or a task model. Check ...
                        if selected_object.kind_of?(child_model)
                            task = selected_object # selected an instance explicitely
                            child_model = task.model
                        else
                            child_model = selected_object
                        end

                        if (dependent_model < DataSource) && !(dependent_model < Roby::Task)
                            if selected_object_name
                                _, *selection_name = selected_object_name.split '.'
                                selection_name = if selection_name.empty? then nil
                                                 else selection_name.join(".")
                                                 end
                            end

                            target_source_name = child_model.find_matching_source(dependent_model, selection_name)
                            if !child_model.main_data_source?(target_source_name)
                                port_mappings = DataSourceModel.compute_port_mappings(dependent_model, child_model, target_source_name)
                                apply_port_mappings(connections, child_name, port_mappings)
                            end
                        end
                    end

                    if !task
                        # Filter out arguments: check if some of the mappings
                        # are prefixed by "child_name.", in which case we
                        # transform the mapping for our child
                        child_arguments = arguments.dup
                        child_selection = Hash.new
                        arguments[:selection].each do |from, to|
                            if from.respond_to?(:to_str) && from =~ /^#{child_name}\./
                                from = from.gsub(/^#{child_name}\./, '')
                                sel_from = engine.apply_selection(from)
                                from = sel_from || from
                            end
                            child_arguments[:selection][from] = to
                        end
                        task = child_model.instanciate(engine, child_arguments)
                    end

                    children_tasks[child_name] = task
                    self_task.depends_on(task, :model => [dependent_model, dependent_model.meaningful_arguments(task.arguments)], :roles => role)
                end

                connections.each do |(out_name, in_name), mappings|
                    children_tasks[out_name].connect_to(children_tasks[in_name], mappings)
                end
                self_task
            end
        end

        # Module in which all composition models are registered
        module Compositions
        end

        class Composition < Component
            extend CompositionModel

            def ids; arguments[:ids] end
        end
    end
end

