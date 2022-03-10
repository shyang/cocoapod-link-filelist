
module Pod
  class Target
    class BuildSettings
      class AggregateTargetSettings

        def device_sdk_path
          @device_sdk_path ||= `xcrun --sdk iphoneos --show-sdk-path`.strip
        end

        def simulator_sdk_path
          @simulator_sdk_path ||= `xcrun --sdk iphonesimulator --show-sdk-path`.strip
        end

        def find_path_of_lib(lib_name)
          storage_lib_name = "lib" + lib_name + ".tbd"
          library_path = File.expand_path(storage_lib_name, '/usr/lib')
          return library_path if File.exist?(device_sdk_path + library_path)
        end

        def find_path_of_framework(framework_name)
          storage_framework_path = framework_name + ".framework/" + framework_name + ".tbd"
          framework_path = File.expand_path(storage_framework_path, '/System/Library/Frameworks')
          return framework_path if File.exist?(device_sdk_path + framework_path)
        end

        # xcconfig 总所有配置的 key => value
        def to_h
          hash = super()
          hash.delete('LIBRARY_SEARCH_PATHS')
          hash.delete('FRAMEWORK_SEARCH_PATHS')

          if defined?(@ld_flags_for_any_arch) && !@ld_flags_for_any_arch.blank?
            hash['OTHER_LDFLAGS[arch=*]'] = @ld_flags_for_any_arch
          end

          if defined?(@ld_flags_for_device) && !@ld_flags_for_device.blank?
            hash['OTHER_LDFLAGS[arch=armv7]']  = @ld_flags_for_device
            hash['OTHER_LDFLAGS[arch=arm64]']  = @ld_flags_for_device
            hash['OTHER_LDFLAGS[arch=i386]']   = @ld_flags_for_simulator
            hash['OTHER_LDFLAGS[arch=x86_64]'] = @ld_flags_for_simulator
          end
          hash
        end

        def _raw_other_ldflags
          # 每个 Pod 自带内部的 .a .framework
          vendored_paths = {}
          pod_targets.each do |pod_target|
            pod_target.file_accessors.each do |acc|
              (acc.vendored_dynamic_libraries + acc.vendored_static_libraries).each do |l|
                library_name = File.basename(l, l.extname).sub(/^lib/, '')
                vendored_paths[library_name] = l.to_s
              end

              (acc.vendored_dynamic_frameworks + acc.vendored_static_frameworks).each do |l|
                framework_name = File.basename(l, l.extname)
                vendored_paths[framework_name] = l.to_s
              end
            end
          end

          base_file_path = "#{target.name}.#{@configuration_name.to_s.downcase}"
          xcconfig_dir = File.expand_path("Target Support Files/#{target.name}", self.target.sandbox.root.to_s)

          vendored_file_path = File.expand_path("#{base_file_path}.vendored.filelist", xcconfig_dir)
          vendored_files = []

          intermediates_file_path = File.expand_path("#{base_file_path}.intermediates.filelist", xcconfig_dir)
          intermediates_files = []

          system_file_path = File.expand_path("#{base_file_path}.system.filelist", xcconfig_dir)
          system_files = []

          ld_flags = []
          ld_flags << '-ObjC' if requires_objc_linker_flag?
          if requires_fobjc_arc?
            ld_flags << '-fobjc-arc'
          end

          libraries.each do |library_name|
            next if library_name == "stdc++" # libstdc++.dylib
            library_path = vendored_paths[library_name]
            if library_path
              vendored_files << library_path
            else
              library_path = find_path_of_lib(library_name)
              if library_path
                system_files << library_path
              else
                intermediates_files << "#{library_name}/lib#{library_name}.a"
              end
            end
          end

          frameworks.each do |framework_name|
            framework_path = nil
            framework_path = vendored_paths[framework_name] + "/" + framework_name unless vendored_paths[framework_name].nil?
            if framework_path
              vendored_files << framework_path
            else
              framework_path = find_path_of_framework(framework_name)
              if framework_path
                system_files << framework_path
              else
                raise "Can't find framework #{framework_name}"
              end
            end
          end

          extra_ld_info = "$(inherited) "
          if !intermediates_files.empty?
            File.open(intermediates_file_path, 'w') do |f|
              f.puts(intermediates_files)
            end
            extra_ld_info += "-filelist \"#{intermediates_file_path},${PODS_CONFIGURATION_BUILD_DIR}\" "
          end

          if !vendored_files.empty?
            File.open(vendored_file_path, 'w') do |f|
              f.puts(vendored_files)
            end
            extra_ld_info += "-filelist \"#{vendored_file_path}\""
          end

          if !intermediates_files.empty? || !vendored_files.empty?
            @ld_flags_for_any_arch = extra_ld_info.strip
          end

          if !system_files.empty?
            File.open(system_file_path, 'w') do |f|
              f.puts(system_files)
            end
            @ld_flags_for_device = "$(inherited) -filelist \"#{system_file_path},#{device_sdk_path}\""
            @ld_flags_for_simulator = "$(inherited) -filelist \"#{system_file_path},#{simulator_sdk_path}\""
          end

          weak_frameworks.each { |f| ld_flags << '-weak_framework' << %("#{f}") }
          ld_flags
        end

        attr_accessor :ld_flags_for_any_arch
        attr_accessor :ld_flags_for_device
        attr_accessor :ld_flags_for_simulator
      end
    end
  end
end
