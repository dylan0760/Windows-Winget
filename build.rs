fn main() {
    #[cfg(windows)]
    {
        let mut resource = winres::WindowsResource::new();
        resource.set_icon("assets/app.ico");
        // Test executables must run non-interactively; only the shipped release
        // binary requests elevation when Windows launches it.
        if std::env::var("PROFILE").as_deref() == Ok("release") {
            resource.set_manifest_file("assets/app.manifest");
        }
        resource.set("FileDescription", "Windows Toolbox");
        resource.set("ProductName", "Windows Toolbox");
        resource.set("OriginalFilename", "windows-toolbox.exe");
        resource
            .compile()
            .expect("failed to compile Windows application resources");

        // GNU-family linkers may discard a resource-only static archive because
        // it exports no referenced symbols. Link the generated COFF object
        // directly so the icon is retained in GNU and GNULLVM release builds.
        #[cfg(target_env = "gnu")]
        {
            let resource_object =
                std::path::PathBuf::from(std::env::var_os("OUT_DIR").expect("OUT_DIR is not set"))
                    .join("resource.o");
            println!("cargo:rustc-link-arg={}", resource_object.display());
        }
    }
}
