require 'libvirt'

module Commands
    # Command to be called when the user wants to create a new VM
    class Create < Commands::Base
        def create
            File.write("#{@conf['name']}.tf", @tf_conf)
            system('terraform init')
            detect_resources
            system('terraform apply')

            puts('Would you like to restart networking? This is necessary in Alpine if a new network configuration has been applied.')
            print('Enter a value (yes/no): ')
            response = STDIN.gets.chomp

            return unless response == 'yes'
            `virsh qemu-agent-command #{@conf['name']} '{"execute":"guest-exec", "arguments": {"path":"/sbin/service", "arg": ["networking", "restart"]}}'`
        end
    end
end
