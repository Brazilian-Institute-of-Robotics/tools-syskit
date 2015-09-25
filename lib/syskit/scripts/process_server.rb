require 'roby'
require 'orocos'
require 'orocos/remote_processes'
require 'orocos/remote_processes/server'

require 'optparse'

options = Hash[host: 'localhost']
parser = OptionParser.new
server_port = Orocos::RemoteProcesses::DEFAULT_PORT
Roby::Application.host_options(parser, options)
parser.parse(ARGV)

class ProcessServer < Orocos::RemoteProcesses::Server
    attr_reader :app
    def initialize(app, port: Orocos::RemoteProcesses::Server::DEFAULT_PORT)
        @app = app
        super(wait: false, output: "%m-%p.txt")
    end

    def create_log_dir(log_dir, time_tag, metadata = Hash.new)
        if log_dir
            app.log_base_dir = log_dir
        end
        app.add_app_metadata(metadata)
        app.find_and_create_log_dir(time_tag)
        Server.debug "  #{app.log_dir} created for #{time_tag}"
    end

    def start_process(name, deployment_name, name_mappings, options)
        options = [working_directory: app.log_dir].merge(options)
        super(name, deployment_name, name_mappings, options)
    end
end

Orocos::CORBA.name_service.ip = options[:host]
Orocos.disable_sigchld_handler = true
Orocos.initialize
ProcessServer.new(Roby.app, port: server_port).exec

