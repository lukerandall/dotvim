#!/usr/bin/env ruby
#
## from http://errtheblog.com/posts/89-huba-huba
#
home = File.expand_path('~')

%w(vimrc).each do |file|
  next if file =~ /install|readme/i
  target = File.join(home, ".#{File.basename(file)}")
  puts `ln -svf #{File.expand_path file} #{target}`
end

puts `git submodule update --init`

puts `cd bundle/command-t; rvm use system; rake clobber; rake make`

