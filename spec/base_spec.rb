require 'jiffy'

# rubocop:disable Metrics/BlockLength

def valid_tf?
    `terraform init`
    `terraform validate`
    return true
rescue StandardError
    false
end

describe Commands::Base do
    describe '#initialize' do
        context 'with basic node and global configurations' do
            before do
                test_conf = %(
name: jiffy-test
flavor: generic
pass_hash: $1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1
memory: 1024
vcpu: 1
)
                @base = Commands::Base.new(test_conf, false, false, false)

                File.write('test.tf', @base.tf_conf)
            end

            it 'parses YAML correctly' do
                expect(@base.conf).to match(
                    'flavor' => 'generic',
                    'memory' => 1024,
                    'vcpu' => 1,
                    'name' => 'jiffy-test',
                    'pass_hash' => '$1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1'
                )
            end

            it 'generates a valid terraform config' do
                expect(valid_tf?).to be true
            end
        end

        context 'with a base image' do
            before do
                test_conf = %(
name: jiffy-test
flavor: generic
pass_hash: $1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1
memory: 1024
vcpu: 1
image:
    location: /test_dir/test.qcow2
    user: root
    password: debbase
    id: debian9-base
)

                @base = Commands::Base.new(test_conf, false, false, false)

                File.write('test.tf', @base.tf_conf)
            end

            it 'parses YAML correctly' do
                expect(@base.conf).to match(
                    'flavor' => 'generic',
                    'memory' => 1024,
                    'vcpu' => 1,
                    'name' => 'jiffy-test',
                    'pass_hash' => '$1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1',
                    'image' => {
                        'location' => '/test_dir/test.qcow2',
                        'user' => 'root',
                        'password' => 'debbase',
                        'id' => 'debian9-base'
                    }
                )
            end

            it 'generates a valid terraform config' do
                expect(valid_tf?).to be true
            end
        end

        context 'with a nat network' do
            before do
                test_conf = %(
name: jiffy-test
flavor: generic
pass_hash: $1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1
memory: 1024
vcpu: 1

network:
    mode: nat
    addresses: 192.168.0.0/24
    id: default
)

                @base = Commands::Base.new(test_conf, false, false, false)

                File.write('test.tf', @base.tf_conf)
            end

            it 'parses YAML correctly' do
                expect(@base.conf).to match(
                    'flavor' => 'generic',
                    'memory' => 1024,
                    'vcpu' => 1,
                    'name' => 'jiffy-test',
                    'pass_hash' => '$1$GlI5CHXg$VtEtQUo/CJto0Q5MbIXaB1',
                    'network' => {
                        'mode' => 'nat',
                        'addresses' => '192.168.0.0/24',
                        'id' => 'default'
                    }
                )
            end

            it 'generates a valid terraform config' do
                expect(valid_tf?).to be true
            end
        end
    end
end
# rubocop:enable Metrics/BlockLength
