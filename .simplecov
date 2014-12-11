$stderr.puts "\n\n>>> Enabling coverage report.\n\n"
SimpleCov.start do
	add_filter 'spec'
	add_group "Needing tests" do |file|
		file.covered_percent < 90
	end
end
