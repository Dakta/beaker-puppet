extend BeakerPuppet::Install::Puppet5
extend Beaker::DSL::InstallUtils::FOSSUtils

test_name "Install Packages"

dev_builds_url  = ENV['DEV_BUILDS_URL'] || 'http://builds.delivery.puppetlabs.net'
nightly_builds_url = ENV['NIGHTLY_BUILDS_URL'] || "http://ravi.puppetlabs.com"

step "Install puppet-agent..." do
  sha = ENV['SHA']
  install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{sha}/artifacts/#{sha}.yaml", hosts)
end

step "Install puppetserver..." do
  if ENV['SERVER_VERSION'].nil? || ENV['SERVER_VERSION'] == 'latest'
    install_puppetlabs_dev_repo(master, 'puppetserver', 'latest', nil, :dev_builds_url => nightly_builds_url)
    master.install_package('puppetserver')
  else
    server_version = ENV['SERVER_VERSION']
    install_from_build_data_url('puppetserver', "#{dev_builds_url}/puppetserver/#{server_version}/artifacts/#{server_version}.yaml", master)
  end
end

# make sure install is sane, beaker has already added puppet and ruby
# to PATH in ~/.ssh/environment
agents.each do |agent|
  on agent, puppet('--version')
  ruby = ruby_command(agent)
  on agent, "#{ruby} --version"
end

# Get a rough estimate of clock skew among hosts
times = []
hosts.each do |host|
  ruby = ruby_command(host)
  on(host, "#{ruby} -e 'puts Time.now.strftime(\"%Y-%m-%d %T.%L %z\")'") do |result|
    times << result.stdout.chomp
  end
end
times.map! do |time|
  (Time.strptime(time, "%Y-%m-%d %T.%L %z").to_f * 1000.0).to_i
end
diff = times.max - times.min
if diff < 60000
  logger.info "Host times vary #{diff} ms"
else
  logger.warn "Host times vary #{diff} ms, tests may fail"
end

configure_gem_mirror(hosts)
