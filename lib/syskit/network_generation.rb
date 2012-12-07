module Syskit
    # Namespace for all the functionality that allows to generate a complete
    # network from a set of requirements
    module NetworkGeneration
    end
end

require 'syskit/network_generation/dataflow_computation'
require 'syskit/network_generation/dataflow_dynamics'
require 'syskit/network_generation/network_merge_solver'
require 'syskit/network_generation/engine'
require 'syskit/network_generation/logger'
