require 'rubygems'
require 'subexec'
require 'open-uri'
require 'json'
require 'netaddr'

def range_to_cidr(startr, endr)
  return ["ipv6"] if startr.include?(":")
  ip_net_range = NetAddr.range(startr,endr,:Inclusive => true, :Objectify => false)
  NetAddr.merge(ip_net_range, :Objectify => false, :Short => true)
end

target_org = ARGV[0]

puts "[!] Starting NetList script..."

orgs = {}
org_search_results = Subexec.run("curl -s -H \"Accept: application/json\" \"http://whois.arin.net/rest/orgs;name=#{target_org}*\"").output
begin
  org_search_results = JSON.parse(org_search_results)
  org_search_results["orgs"]["orgRef"].each do |org|
    orgs[org["@name"]] = {:handle => org["@handle"] }
  end
rescue
  ""
end

puts "[!] Found #{orgs.count} organizations matching your query, \"#{ARGV[0]}\"."
puts "[!] Starting network lookup queries...\n\n"

orgs.each do |org, info|
  orgs[org][:nets] = {}
  nets_search_results = Subexec.run("curl -s -H \"Accept: application/json\" \"http://whois.arin.net/rest/org/#{info[:handle]}/nets\"").output
  begin
    nets_search_results = JSON.parse(nets_search_results)
    nets_search_results["nets"]["netRef"] = [nets_search_results["nets"]["netRef"]] if nets_search_results["nets"]["netRef"].class != Array
    nets_search_results["nets"]["netRef"].each do |info|
      orgs[org][:nets][info["@name"]] = { :start => info["@startAddress"], :end => info["@endAddress"] }
    end
  rescue
    ""
  end
end

orgs.each do |k, v|
  puts "----- #{k} (#{v[:handle]}) -----"
  v[:nets].each do |netk, netv|
    puts "\n* #{netk}\n  #{netv[:start]} - #{netv[:end]}   => #{range_to_cidr(netv[:start], netv[:end]).join(', ')}\n"
  end
  puts "\n"
end

puts "[!] Done. Enjoy!"

