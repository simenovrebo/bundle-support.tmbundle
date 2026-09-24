# OSX::Keychain: internet passwords in the user’s keychain, with the security command.
#
# It replaces keychain.bundle, a compiled extension that couldn’t run on Apple Silicon.
#
#   OSX::Keychain.internet_password_for(:account => 'foo', :server => 'bar', :protocol => 'mysq') # => "secret" or nil
#   OSX::Keychain.set_internet_password_for(:account => 'foo', :server => 'bar', :protocol => 'mysq', :password => 'secret')
#   OSX::Keychain.destroy_internet_password_for(:account => 'foo', :server => 'bar', :protocol => 'mysq')
#
# The protocol is a four-character code, like “mysq” or “pgsq”.

module OSX
  module Keychain
    SECURITY = '/usr/bin/security'

    class << self
      def internet_password_for(options)
        output, ok = security('find-internet-password', options, '-w')
        ok ? output.chomp : nil
      end

      def set_internet_password_for(options)
        raise ArgumentError, 'password required' unless options[:password]
        output, ok = security('add-internet-password', options, '-U', '-w', options[:password].to_s)
        raise RuntimeError, output.strip unless ok
        true
      end

      def destroy_internet_password_for(options)
        output, ok = security('delete-internet-password', options)
        ok
      end

      private

      def security(command, options, *extra)
        [:account, :server, :protocol].each do |key|
          raise ArgumentError, "#{key} required" unless options[key]
        end
        args = [command, '-a', options[:account], '-s', options[:server], '-r', options[:protocol]] + extra
        output = IO.popen([SECURITY, *args].map { |arg| shell_escape(arg.to_s) }.join(' ') + ' 2>&1') { |io| io.read }
        [output, $?.success?]
      end

      def shell_escape(str)
        "'" + str.gsub("'", "'\\\\''") + "'"
      end
    end
  end
end
