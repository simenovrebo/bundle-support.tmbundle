# This is used by bin/ruby18 to fix the hardcoded loadpath
$:.each { |path| path.sub!(%r{^/usr/local/textmate-ruby-1\.8\.7(?=/|$)}, "#{ENV['HOME']}/Library/Application Support/TextMate/Ruby/1.8.7-p374") }
