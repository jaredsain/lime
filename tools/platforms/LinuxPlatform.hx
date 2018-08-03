package;


import haxe.io.Path;
import haxe.Template;
import lime.tools.Architecture;
import lime.tools.AssetHelper;
import lime.tools.AssetType;
import lime.tools.CPPHelper;
import lime.tools.DeploymentHelper;
import hxp.FileHelper;
import hxp.Haxelib;
import lime.tools.JavaHelper;
import hxp.Log;
import lime.tools.NekoHelper;
import lime.tools.NodeJSHelper;
import hxp.PathHelper;
import lime.tools.Platform;
import hxp.PlatformHelper;
import lime.tools.PlatformTarget;
import hxp.ProcessHelper;
import lime.tools.Project;
import lime.tools.ProjectHelper;
import hxp.WatchHelper;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;


class LinuxPlatform extends PlatformTarget {


	private var applicationDirectory:String;
	private var executablePath:String;
	private var is64:Bool;
	private var isRaspberryPi:Bool;
	private var targetType:String;


	public function new (command:String, _project:Project, targetFlags:Map<String, String> ) {

		super (command, _project, targetFlags);

		for (architecture in project.architectures) {

			if (!targetFlags.exists ("32") && architecture == Architecture.X64) {

				is64 = true;

			} else if (architecture == Architecture.ARMV7) {

				isRaspberryPi = true;

			}

		}

		if (project.targetFlags.exists ("rpi")) {

			isRaspberryPi = true;
			is64 = false;

		}

		if (project.targetFlags.exists ("neko") || project.target != cast PlatformHelper.hostPlatform) {

			targetType = "neko";

		} else if (project.targetFlags.exists ("hl")) {

			targetType = "hl";

		} else if (project.targetFlags.exists ("nodejs")) {

			targetType = "nodejs";

		} else if (project.targetFlags.exists ("java")) {

			targetType = "java";

		} else {

			targetType = "cpp";

		}

		targetDirectory = PathHelper.combine (project.app.path, project.config.getString ("linux.output-directory", targetType == "cpp" ? "linux" : targetType));
		targetDirectory = StringTools.replace (targetDirectory, "arch64", is64 ? "64" : "");
		applicationDirectory = targetDirectory + "/bin/";
		executablePath = PathHelper.combine (applicationDirectory, project.app.file);

	}


	public override function build ():Void {

		var hxml = targetDirectory + "/haxe/" + buildType + ".hxml";

		PathHelper.mkdir (targetDirectory);

		if (!project.targetFlags.exists ("static") || targetType != "cpp") {

			var targetSuffix = (targetType == "hl") ? ".hdll" : null;

			for (ndll in project.ndlls) {

				if (isRaspberryPi) {

					ProjectHelper.copyLibrary (project, ndll, "RPi", "", (ndll.haxelib != null && (ndll.haxelib.name == "hxcpp" || ndll.haxelib.name == "hxlibc")) ? ".dso" : ".ndll", applicationDirectory, project.debug, targetSuffix);

				} else {

					ProjectHelper.copyLibrary (project, ndll, "Linux" + (is64 ? "64" : ""), "", (ndll.haxelib != null && (ndll.haxelib.name == "hxcpp" || ndll.haxelib.name == "hxlibc")) ? ".dso" : ".ndll", applicationDirectory, project.debug, targetSuffix);

				}

			}

		}

		if (targetType == "neko") {

			ProcessHelper.runCommand ("", "haxe", [ hxml ]);

			if (noOutput) return;

			if (isRaspberryPi) {

				NekoHelper.createExecutable (project.templatePaths, "rpi", targetDirectory + "/obj/ApplicationMain.n", executablePath);
				NekoHelper.copyLibraries (project.templatePaths, "rpi", applicationDirectory);

			} else {

				NekoHelper.createExecutable (project.templatePaths, "linux" + (is64 ? "64" : ""), targetDirectory + "/obj/ApplicationMain.n", executablePath);
				NekoHelper.copyLibraries (project.templatePaths, "linux" + (is64 ? "64" : ""), applicationDirectory);

			}

		} else if (targetType == "hl") {

			ProcessHelper.runCommand ("", "haxe", [ hxml ]);

			if (noOutput) return;

			FileHelper.copyFile (targetDirectory + "/obj/ApplicationMain" + (project.debug ? "-Debug" : "") + ".hl", PathHelper.combine (applicationDirectory, project.app.file + ".hl"));

		} else if (targetType == "nodejs") {

			ProcessHelper.runCommand ("", "haxe", [ hxml ]);
			//NekoHelper.createExecutable (project.templatePaths, "linux" + (is64 ? "64" : ""), targetDirectory + "/obj/ApplicationMain.n", executablePath);
			//NekoHelper.copyLibraries (project.templatePaths, "linux" + (is64 ? "64" : ""), applicationDirectory);

		} else if (targetType == "java") {

			var libPath = PathHelper.combine (PathHelper.getHaxelib (new Haxelib ("lime")), "templates/java/lib/");

			ProcessHelper.runCommand ("", "haxe", [ hxml, "-java-lib", libPath + "disruptor.jar", "-java-lib", libPath + "lwjgl.jar" ]);
			//ProcessHelper.runCommand ("", "haxe", [ hxml ]);

			if (noOutput) return;

			var haxeVersion = project.environment.get ("haxe_ver");
			var haxeVersionString = "3404";

			if (haxeVersion.length > 4) {

				haxeVersionString = haxeVersion.charAt (0) + haxeVersion.charAt (2) + (haxeVersion.length == 5 ? "0" + haxeVersion.charAt (4) : haxeVersion.charAt (4) + haxeVersion.charAt (5));

			}

			ProcessHelper.runCommand (targetDirectory + "/obj", "haxelib", [ "run", "hxjava", "hxjava_build.txt", "--haxe-version", haxeVersionString ]);
			FileHelper.recursiveCopy (targetDirectory + "/obj/lib", PathHelper.combine (applicationDirectory, "lib"));
			FileHelper.copyFile (targetDirectory + "/obj/ApplicationMain" + (project.debug ? "-Debug" : "") + ".jar", PathHelper.combine (applicationDirectory, project.app.file + ".jar"));
			JavaHelper.copyLibraries (project.templatePaths, "Linux" + (is64 ? "64" : ""), applicationDirectory);

		} else {

			var haxeArgs = [ hxml ];
			var flags = [];

			if (is64) {

				haxeArgs.push ("-D");
				haxeArgs.push ("HXCPP_M64");
				flags.push ("-DHXCPP_M64");

			} else {

				haxeArgs.push ("-D");
				haxeArgs.push ("HXCPP_M32");
				flags.push ("-DHXCPP_M32");

			}

			if (!project.targetFlags.exists ("static")) {

				ProcessHelper.runCommand ("", "haxe", haxeArgs);

				if (noOutput) return;

				CPPHelper.compile (project, targetDirectory + "/obj", flags);

				FileHelper.copyFile (targetDirectory + "/obj/ApplicationMain" + (project.debug ? "-debug" : ""), executablePath);

			} else {

				ProcessHelper.runCommand ("", "haxe", haxeArgs.concat ([ "-D", "static_link" ]));

				if (noOutput) return;

				CPPHelper.compile (project, targetDirectory + "/obj", flags.concat ([ "-Dstatic_link" ]));
				CPPHelper.compile (project, targetDirectory + "/obj", flags, "BuildMain.xml");

				FileHelper.copyFile (targetDirectory + "/obj/Main" + (project.debug ? "-debug" : ""), executablePath);

			}

		}

		if (PlatformHelper.hostPlatform != WINDOWS && (targetType != "nodejs" && targetType != "java")) {

			ProcessHelper.runCommand ("", "chmod", [ "755", executablePath ]);

		}

	}


	public override function clean ():Void {

		if (FileSystem.exists (targetDirectory)) {

			PathHelper.removeDirectory (targetDirectory);

		}

	}


	public override function deploy ():Void {

		DeploymentHelper.deploy (project, targetFlags, targetDirectory, "Linux " + (is64 ? "64" : "32") + "-bit");

	}


	public override function display ():Void {

		Sys.println (getDisplayHXML ());

	}


	private function generateContext ():Dynamic {

		// var project = project.clone ();

		if (isRaspberryPi) {

			project.haxedefs.set ("rpi", 1);

		}

		var context = project.templateContext;

		context.NEKO_FILE = targetDirectory + "/obj/ApplicationMain.n";
		context.NODE_FILE = targetDirectory + "/bin/ApplicationMain.js";
		context.HL_FILE = targetDirectory + "/obj/ApplicationMain.hl";
		context.CPP_DIR = targetDirectory + "/obj/";
		context.BUILD_DIR = project.app.path + "/linux" + (is64 ? "64" : "") + (isRaspberryPi ? "-rpi" : "");
		context.WIN_ALLOW_SHADERS = false;

		return context;

	}


	private function getDisplayHXML ():String {

		var hxml = PathHelper.findTemplate (project.templatePaths, targetType + "/hxml/" + buildType + ".hxml");
		var template = new Template (File.getContent (hxml));

		var context = generateContext ();
		context.OUTPUT_DIR = targetDirectory;

		return template.execute (context) + "\n-D display";

	}


	public override function rebuild ():Void {

		var commands = [];

		if (targetFlags.exists ("rpi")) {

			commands.push ([ "-Dlinux", "-Drpi", "-Dtoolchain=linux", "-DBINDIR=RPi", "-DCXX=arm-linux-gnueabihf-g++", "-DHXCPP_M32", "-DHXCPP_STRIP=arm-linux-gnueabihf-strip", "-DHXCPP_AR=arm-linux-gnueabihf-ar", "-DHXCPP_RANLIB=arm-linux-gnueabihf-ranlib" ]);

		} else {

			if (!targetFlags.exists ("32") && PlatformHelper.hostArchitecture == X64) {

				commands.push ([ "-Dlinux", "-DHXCPP_M64" ]);

			}

			if (!targetFlags.exists ("64") && (command == "rebuild" || PlatformHelper.hostArchitecture == X86)) {

				commands.push ([ "-Dlinux", "-DHXCPP_M32" ]);

			}

		}

		CPPHelper.rebuild (project, commands);

	}


	public override function run ():Void {

		var arguments = additionalArguments.copy ();

		if (Log.verbose) {

			arguments.push ("-verbose");

		}

		if (targetType == "hl") {

			ProcessHelper.runCommand (applicationDirectory, "hl", [ project.app.file + ".hl" ].concat (arguments));

		} else if (targetType == "nodejs") {

			NodeJSHelper.run (project, targetDirectory + "/bin/ApplicationMain.js", arguments);

		} else if (targetType == "java") {

			ProcessHelper.runCommand (applicationDirectory, "java", [ "-jar", project.app.file + ".jar" ].concat (arguments));

		} else if (project.target == cast PlatformHelper.hostPlatform) {

			arguments = arguments.concat ([ "-livereload" ]);
			ProcessHelper.runCommand (applicationDirectory, "./" + Path.withoutDirectory (executablePath), arguments);

		}

	}


	public override function update ():Void {

		AssetHelper.processLibraries (project, targetDirectory);

		// project = project.clone ();
		//initialize (project);

		for (asset in project.assets) {

			if (asset.embed && asset.sourcePath == "") {

				var path = PathHelper.combine (targetDirectory + "/obj/tmp", asset.targetPath);
				PathHelper.mkdir (Path.directory (path));
				AssetHelper.copyAsset (asset, path);
				asset.sourcePath = path;

			}

		}

		if (project.targetFlags.exists ("xml")) {

			project.haxeflags.push ("-xml " + targetDirectory + "/types.xml");

		}

		var context = generateContext ();
		context.OUTPUT_DIR = targetDirectory;

		if (targetType == "cpp" && project.targetFlags.exists ("static")) {

			for (i in 0...project.ndlls.length) {

				var ndll = project.ndlls[i];

				if (ndll.path == null || ndll.path == "") {

					if (isRaspberryPi) {

						context.ndlls[i].path = PathHelper.getLibraryPath (ndll, "RPi", "lib", ".a", project.debug);

					} else {

						context.ndlls[i].path = PathHelper.getLibraryPath (ndll, "Linux" + (is64 ? "64" : ""), "lib", ".a", project.debug);

					}

				}

			}

		}

		PathHelper.mkdir (targetDirectory);
		PathHelper.mkdir (targetDirectory + "/obj");
		PathHelper.mkdir (targetDirectory + "/haxe");
		PathHelper.mkdir (applicationDirectory);

		//SWFHelper.generateSWFClasses (project, targetDirectory + "/haxe");

		ProjectHelper.recursiveSmartCopyTemplate (project, "haxe", targetDirectory + "/haxe", context);
		ProjectHelper.recursiveSmartCopyTemplate (project, targetType + "/hxml", targetDirectory + "/haxe", context);

		if (targetType == "cpp" && project.targetFlags.exists ("static")) {

			ProjectHelper.recursiveSmartCopyTemplate (project, "cpp/static", targetDirectory + "/obj", context);

		}

		//context.HAS_ICON = IconHelper.createIcon (project.icons, 256, 256, PathHelper.combine (applicationDirectory, "icon.png"));
		for (asset in project.assets) {

			var path = PathHelper.combine (applicationDirectory, asset.targetPath);

			if (asset.embed != true) {

				if (asset.type != AssetType.TEMPLATE) {

					PathHelper.mkdir (Path.directory (path));
					AssetHelper.copyAssetIfNewer (asset, path);

				} else {

					PathHelper.mkdir (Path.directory (path));
					AssetHelper.copyAsset (asset, path, context);

				}

			}

		}

	}


	public override function watch ():Void {

		var dirs = WatchHelper.processHXML (getDisplayHXML (), project.app.path);
		var command = ProjectHelper.getCurrentCommand ();
		WatchHelper.watch (command, dirs);

	}


	@ignore public override function install ():Void {}
	@ignore public override function trace ():Void {}
	@ignore public override function uninstall ():Void {}


}