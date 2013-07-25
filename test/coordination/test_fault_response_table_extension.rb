require 'syskit/test'

describe Syskit::Coordination::Models::FaultResponseTableExtension do
    include Syskit::SelfTest

    it "should attach the associated data monitoring tables to the plan it is attached to" do
        component_m = Syskit::TaskContext.new_submodel
        fault_m = Roby::Coordination::FaultResponseTable.new_submodel
        data_m = Syskit::Coordination::DataMonitoringTable.new_submodel(component_m)
        fault_m.use_data_monitoring_table data_m
        flexmock(plan).should_receive(:use_data_monitoring_table).with(data_m).once
        plan.use_fault_response_table fault_m
    end

    it "should allow using monitors as fault descriptions, and properly set them up at runtime" do
        recorder = flexmock
        response_task_m = Roby::Task.new_submodel do
            terminates
        end
        component_m = Syskit::TaskContext.new_submodel(:name => 'Test') do
            output_port 'out1', '/int'
            output_port 'out2', '/int'
        end
        table_model = Roby::Coordination::FaultResponseTable.new_submodel do
            data_monitoring(component_m) do
                monitor("threshold", out1_port).
                    trigger_on do |sample|
                        recorder.called(sample)
                        sample > 10
                    end.
                    raise_exception
            end
            on_fault threshold_monitor do
                locate_on_origin
                response = task(response_task_m)
                execute response
            end
        end

        plan.use_fault_response_table table_model
        assert_equal Hash[table_model.data_monitoring_tables.first => []], plan.data_monitoring_tables
        stub_syskit_deployment_model(component_m)
        component = deploy(component_m)
        syskit_start_component(component)
        process_events
        process_events

        recorder.should_receive(:called).with(5).once.ordered
        recorder.should_receive(:called).with(11).once.ordered
        component.orocos_task.out1.write(5)
        process_events
        component.orocos_task.out1.write(11)
        process_events

        assert(response_task = plan.find_tasks(response_task_m).running.first)
    end
end