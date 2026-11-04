#!/usr/bin/env ruby
# Add newly created source files without regenerating or overwriting project settings.
require 'xcodeproj'
root = File.expand_path('..', __dir__)
Dir.chdir(root)
project = Xcodeproj::Project.open('Noted.xcodeproj')
app = project.targets.find { |t| t.name == 'Noted' }
defaults = project.files.find { |f| f.path == 'Defaults.xcconfig' }
ui = project.targets.find { |t| t.name == 'NotedUITests' }
unless ui
  ui = project.new_target(:ui_test_bundle, 'NotedUITests', :ios, '27.0')
  ui.add_dependency(app)
  ui.build_configurations.each do |c|
    c.base_configuration_reference = defaults
    c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'$(NOTED_BUNDLE_ID).UITests', 'GENERATE_INFOPLIST_FILE'=>'YES', 'CODE_SIGN_STYLE'=>'Automatic', 'SWIFT_VERSION'=>'5.0', 'TARGETED_DEVICE_FAMILY'=>'1', 'SUPPORTED_PLATFORMS'=>'iphoneos', 'SDKROOT'=>'iphoneos', 'TEST_TARGET_NAME'=>'Noted'})
  end
end
host = project.targets.find { |t| t.name == 'NotedGateHost' }
if File.directory?('NotedGateHost') && !host
  host = project.new_target(:application, 'NotedGateHost', :ios, '27.0')
  host.build_configurations.each do |c|
    c.base_configuration_reference = defaults
    c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'dev.nguyenhoanghai861.NotedGateHost', 'GENERATE_INFOPLIST_FILE'=>'YES', 'INFOPLIST_KEY_CFBundleDisplayName'=>'Noted Share Check', 'INFOPLIST_KEY_UILaunchScreen_Generation'=>'YES', 'CODE_SIGN_STYLE'=>'Automatic', 'SWIFT_VERSION'=>'5.0', 'TARGETED_DEVICE_FAMILY'=>'1', 'SUPPORTED_PLATFORMS'=>'iphoneos', 'SDKROOT'=>'iphoneos'})
  end
  ui.add_dependency(host)
end
%w[Noted NotedShare Shared NotedTests NotedUITests NotedGateHost].each do |folder|
  next unless File.directory?(folder)
  group = project.main_group.groups.find { |g| g.path == folder } || project.main_group.new_group(folder, folder)
  Dir.glob("#{folder}/**/*.swift").sort.each do |path|
    absolute = File.expand_path(path)
    ref = project.files.find { |f| f.real_path.to_s == absolute } || group.new_file(path.delete_prefix("#{folder}/"))
    names = case folder
    when 'Shared' then %w[Noted NotedShare]
    else [folder]
    end
    names.each do |name|
      target = project.targets.find { |t| t.name == name }
      target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
    end
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
%w[NotedTests].each do |name|
  target = project.targets.find { |t| t.name == name }
  scheme.add_build_target(target, false)
  scheme.add_test_target(target)
end
scheme.set_launch_target(app)
scheme.save_as('Noted.xcodeproj', 'Noted', true)
gate = Xcodeproj::XCScheme.new
gate.add_build_target(app)
gate.add_build_target(host, false) if host
gate.add_build_target(ui, false)
gate.add_test_target(ui)
gate.set_launch_target(app)
gate.save_as('Noted.xcodeproj', 'Noted-DeviceGate', true)
puts 'Source references and real-device test targets updated.'
