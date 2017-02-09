

$sslstrip_output = Array.new

pid = fork do
    IO.popen("./helloworld").each do |line|
      puts line.chomp
    end
end


puts "PID : #{pid}"
Process.kill("HUP", pid)
Process.wait