#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('..', __dir__)
Dir.chdir(root)
path = 'Noted.xcodeproj'
abort 'Project already exists; edit it in Xcode instead of overwriting.' if File.exist?(path)
project = Xcodeproj::Project.new(path)
config = project.main_group.new_group('Config', 'Config')
defaults = config.new_file('Defaults.xcconfig')
config.new_file('Local.xcconfig.example')
app = project.new_target(:application, 'Noted', :ios, '17.0')
ext = project.new_target(:app_extension, 'NotedShare', :ios, '17.0')
tests = project.new_target(:unit_test_bundle, 'NotedTests', :ios, '17.0')
files = {}
%w[Noted NotedShare Shared NotedTests].each do |folder|
  group = project.main_group.new_group(folder, folder)
  Dir.glob("#{folder}/**/*").select { |f| File.file?(f) }.sort.each do |file|
    files[file] = group.new_file(file.delete_prefix("#{folder}/"))
  end
end
app.add_file_references(files.select { |p,_| p.end_with?('.swift') && (p.start_with?('Noted/') || p.start_with?('Shared/')) }.values)
ext.add_file_references(files.select { |p,_| p.end_with?('.swift') && (p.start_with?('NotedShare/') || p.start_with?('Shared/')) }.values)
tests.add_file_references(files.select { |p,_| p.end_with?('.swift') && p.start_with?('NotedTests/') }.values)
app.add_dependency(ext)
tests.add_dependency(app)
embed = app.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
embedded = embed.add_file_reference(ext.product_reference)
embedded.settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
project.build_configurations.each do |c|
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end
[app,ext,tests].each do |target|
  target.build_configurations.each do |c|
    c.base_configuration_reference = defaults
    c.build_settings.merge!({
      'CODE_SIGN_STYLE'=>'Automatic', 'SWIFT_VERSION'=>'5.0',
      'TARGETED_DEVICE_FAMILY'=>'1', 'SUPPORTED_PLATFORMS'=>'iphoneos',
      'SDKROOT'=>'iphoneos', 'CURRENT_PROJECT_VERSION'=>'1', 'MARKETING_VERSION'=>'1.0',
      'ENABLE_USER_SCRIPT_SANDBOXING'=>'YES', 'SWIFT_EMIT_LOC_STRINGS'=>'YES'
    })
  end
end
app.build_configurations.each do |c|
  c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'$(NOTED_BUNDLE_ID)', 'INFOPLIST_FILE'=>'Noted/Supporting/Info.plist', 'GENERATE_INFOPLIST_FILE'=>'NO', 'CODE_SIGN_ENTITLEMENTS'=>'Noted/Noted.entitlements'})
end
ext.build_configurations.each do |c|
  c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'$(NOTED_BUNDLE_ID).Share', 'INFOPLIST_FILE'=>'NotedShare/Info.plist', 'GENERATE_INFOPLIST_FILE'=>'NO', 'CODE_SIGN_ENTITLEMENTS'=>'NotedShare/NotedShare.entitlements', 'APPLICATION_EXTENSION_API_ONLY'=>'YES', 'SKIP_INSTALL'=>'YES'})
end
tests.build_configurations.each do |c|
  c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'$(NOTED_BUNDLE_ID).Tests', 'GENERATE_INFOPLIST_FILE'=>'YES', 'TEST_HOST'=>'$(BUILT_PRODUCTS_DIR)/Noted.app/Noted', 'BUNDLE_LOADER'=>'$(TEST_HOST)'})
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(tests, false)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as(path, 'Noted', true)
puts "Created #{path}; iPhone-only scheme Noted."
