require 'yaml'
require 'erb'
require 'libvirt'
require 'json'

module Commands
    # Common set of defs that all commands will need
    class Base
        attr_accessor :conf, :tf_conf, :attributes_json

        def initialize(conf_str, is_file = true, use_global = true, use_def = true)
            @conf_str = if is_file
                            File.read(conf_str)
                        else
                            conf_str
                        end

            parse_node
            if use_def
                parse_def
            else
                @def_opts = {}
            end
            if use_global
                parse_global
            else
                @global_opts = {}
            end
            @conf = @def_opts.deep_merge(@global_opts).deep_merge(@node_opts)
            fix_empty_arrays

            @attributes_json = JSON.pretty_generate(generate_attributes)

            @tf_conf = create_template
        end

        def fix_empty_arrays
            return unless @conf.key?('chef') && @conf['chef']['enabled'] != false

            unless @conf['chef']['run_list'].is_a?(Array)
                run_array = []
                run_array[0] = @conf['chef']['run_list']
                @conf['chef']['run_list'] = run_array
            end

            if (@conf['flavor'] == 'dmvpn-hub' || @conf['flavor'] == 'dmvpn-client') &&
               @conf['dmvpn']['routes'].nil?
                @conf['dmvpn']['routes'] = []
            end
        end

        def generate_attributes
            attributes = {}
            attributes['interfaces'] = @conf['interfaces']
            attributes['shadow'] = @conf['pass_hash']

            if @conf['flavor'] == 'dmvpn-hub' || @conf['flavor'] == 'dmvpn-client'
                attributes['interfaces']['gre1'] = @conf['dmvpn']['tunnel']
                attributes['interfaces']['gre1']['proto'] = 'static'
                attributes['interfaces']['gre1']['pre-up'] ||= "ip tunnel add $IFACE mode gre ttl 64 tos inherit key #{@conf['dmvpn']['gre_key']} local #{@conf['interfaces']['eth0']['addr']} || true"
                attributes['interfaces']['gre1']['post-down'] ||= 'ip tunnel del $IFACE || true'
                attributes['dmvpn'] = @conf['dmvpn']
                attributes['dmvpn'].delete('tunnel')
                attributes['dmvpn'].delete('gre_key')
                @conf['chef']['run_list'].push("role[#{@conf['flavor']}]")
            end

            if @conf['flavor'] == 'webserver' || @conf['flavor'] == 'load-balancer'
                attributes['webserver'] = @conf['webserver']
                @conf['chef']['run_list'].push("role[#{@conf['flavor']}]")
            end

            attributes['load-balancer'] = @conf['load-balancer'] if @conf['flavor'] == 'load-balancer'

            attributes
        end

        def parse_node
            @node_opts = YAML.safe_load(@conf_str)
        end

        def parse_def
            @def_opts = YAML.load_file("#{path_to_resources}/data/conf/def_conf.yml")
        end

        def parse_global
            location = @node_opts['global_conf']
            location ||= @def_opts['global_conf']
            @global_opts = YAML.load_file(location)
        end

        def create_template
            tf_template = File.read("#{path_to_resources}/data/template/terraform.erb")
            renderer = ERB.new(tf_template, nil, '-')
            renderer.result(binding)
        end

        def get_domain(name)
            conn = Libvirt.open(@conf['uri'])

            begin
                dom = conn.lookup_domain_by_name(name)
            rescue StandardError
                return
            end

            dom.uuid
        end

        def get_net(name)
            conn = Libvirt.open(@conf['uri'])

            begin
                net = conn.lookup_network_by_name(name)
            rescue StandardError
                return
            end

            net.uuid
        end

        def check_vol(vol_name, pool_name = 'default')
            conn = Libvirt.open(@conf['uri'])
            pools = conn.list_all_storage_pools
            pools.each do |pool|
                begin
                    vol_path = pool.lookup_volume_by_name(vol_name).path
                rescue StandardError
                    next
                end
                return vol_path if pool.name == pool_name
            end

            nil
        end

        def detect_resources
            import_state
            import_dom
            import_net
            import_base
            import_vol
        end

        def import_dom
            dom = get_domain(@conf['name'])
            dom_exist = resource_exists("libvirt_domain.#{@conf['name']}")
            `terraform import libvirt_domain.#{@conf['name']} #{dom}` unless dom.nil? || dom_exist
        end

        def import_net
            net_name = "net-#{@conf['network']['id']}"
            net = get_net(net_name)
            net_exist = resource_exists("libvirt_network.#{net_name}")
            `terraform import libvirt_network.#{net_name} #{net}` unless net.nil? || net_exist
        end

        def import_base
            base_name = "base-#{@conf['image']['id']}"
            base_path = check_vol(base_name) if @conf['image']['pool'].nil?
            base_path ||= check_vol(base_name, @conf['image']['pool'])
            base_exist = resource_exists("libvirt_volume.#{base_name}")
            `terraform import libvirt_volume.#{base_name} #{base_path}` unless base_path.nil? || base_exist
        end

        def import_vol
            vol_name = "vol-#{@conf['name']}"
            vol_path = check_vol(vol_name) if @conf['pool'].nil?
            vol_path ||= check_vol(vol_name, @conf['pool'])
            vol_exist = resource_exists("libvirt_volume.#{vol_name}")
            `terraform import libvirt_volume.#{vol_name} #{vol_path}` unless vol_path.nil? || vol_exist
        end

        def import_state
            state_file = File.read('terraform.tfstate')
            @state = JSON.parse(state_file)
        rescue StandardError
            @state = nil
        end

        def resource_exists(res)
            unless @state.nil?
                resources = @state['modules'][0]['resources'].keys
                return true if resources.include? res
            end
            false
        end

        def path_to_resources
            File.join(File.dirname(File.expand_path(__FILE__)), '../..')
        end
    end
end
