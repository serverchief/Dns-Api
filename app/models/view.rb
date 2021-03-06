class View < ActiveRecord::Base
    include SyslogHelper

    RFC1912_NAME = '__rfc1912'
    ANY_NAME     = '__any'

    audited :protect => false

    has_many :domains

    validates_presence_of :name, :key
    validates_associated  :domains

    before_validation :generate_key, :on => :create

    def updated_since?(timestamp)
        self.updated_at > timestamp
    end

    def after_audit
        syslog_audit(self.audits.last)
    end

    def zones_dir
        self.name + '-' + GloboDns::Config::ZONES_DIR
    end
    def zones_file
        self.name + '-' + GloboDns::Config::ZONES_FILE
    end

    def slaves_dir
        self.name + '-' + GloboDns::Config::SLAVES_DIR
    end

    def slaves_file
        self.name + '-' + GloboDns::Config::SLAVES_FILE
    end

    def forwards_dir
        self.name + '-' + GloboDns::Config::FORWARDS_DIR
    end

    def forwards_file
        self.name + '-' + GloboDns::Config::FORWARDS_FILE
    end

    def reverse_dir
        self.name + '-' + GloboDns::Config::REVERSE_DIR
    end
    def reverse_file
        self.name + '-' + GloboDns::Config::REVERSE_FILE
    end

    def self.key_name(view_name)
        view_name + '-key'
    end

    def key_name
        self.class.key_name(self.name)
    end

    def to_bind9_conf(zones_dir, indent = '')
        match_clients = self.clients.present? ? self.clients.split(/\s*;\s*/) : Array.new

        if self.key.present?
            # use some "magic" to figure out the local address used to connect
            # to the master server
            # local_ipaddr = %x(ip route get #{GloboDns::Config::BIND_MASTER_IPADDR})
            local_ipaddr = IO::popen([GloboDns::Config::Binaries::IP, 'route', 'get', GloboDns::Config::BIND_MASTER_IPADDR]) { |io| io.read }
            local_ipaddr = local_ipaddr[/src (#{RecordPatterns::IPV4}|#{RecordPatterns::IPV6})/, 1]

            # then, exclude this address from the list of "match-client"
            # addresses to force the view match using the "key" property
            match_clients.delete("!#{local_ipaddr}")
            match_clients.unshift("!#{local_ipaddr}")

            # additionally, exclude the slave's server address (to enable it to
            # transfer the zones from the view that doesn't match its IP address)
            match_clients.delete("!#{GloboDns::Config::BIND_SLAVE_IPADDR}")
            match_clients.unshift("!#{GloboDns::Config::BIND_SLAVE_IPADDR}")

            key_str = "key \"#{self.key_name}\""
            match_clients.delete(key_str)
            match_clients.unshift(key_str)
        end

        str  = "#{indent}key \"#{self.key_name}\" {\n"
        str << "#{indent}    algorithm hmac-md5;\n"
        str << "#{indent}    secret \"#{self.key}\";\n"
        str << "#{indent}};\n"
        str << "\n"
        str << "#{indent}view \"#{self.name}\" {\n"
        str << "#{indent}    attach-cache       \"globodns-shared-cache\";\n"
        str << "\n"
        str << "#{indent}    match-clients      { #{match_clients.uniq.join('; ')}; };\n" if match_clients.present?
        str << "#{indent}    match-destinations { #{self.destinations}; };\n"             if self.destinations.present?
        str << "\n"
        str << "#{indent}    include \"#{File.join(zones_dir, self.zones_file)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, self.slaves_file)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, self.forwards_file)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, self.reverse_file)}\";\n"
        str << "\n"
        str << "#{indent}    # common zones\n"
        str << "#{indent}    include \"#{File.join(zones_dir, GloboDns::Config::ZONES_FILE)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, GloboDns::Config::SLAVES_FILE)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, GloboDns::Config::FORWARDS_FILE)}\";\n"
        str << "#{indent}    include \"#{File.join(zones_dir, GloboDns::Config::REVERSE_FILE)}\";\n"
        str << "#{indent}};\n\n"
        str
    end

    def generate_key
        Tempfile.open('globodns-key') do |file|
            GloboDns::Util::exec('rndc-confgen', GloboDns::Config::Binaries::RNDC_CONFGEN, '-a', '-r', '/dev/urandom', '-c', file.path, '-k', self.key_name)
            self.key = file.read[/algorithm\s+hmac\-md5;\s*secret\s+"(.*?)";/s, 1];
        end
    end
end
