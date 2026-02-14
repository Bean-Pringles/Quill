#![windows_subsystem = "windows"]

use eframe::egui;
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::sync::{Arc, Mutex};
use std::thread;

// ========== CUSTOMIZE THESE ==========
const CHECKLIST_ITEMS: &[&str] = &[
    "Install Dependencies",
    "Register File Types (Requires Admin)",
    "Create launcher and update PATH",
];
const CUSTOM_ARGS: &[&str] = &[];
// =====================================

// Get the path to the setup script based on OS
fn get_setup_script_path() -> String {
    #[cfg(target_os = "windows")]
    {
        "../../script/windows/quill-setup-windows-x86_64.exe".to_string()
    }
    #[cfg(target_os = "linux")]
    {
        "../../script/linux/quill-setup-linux-x86_64".to_string()
    }
}

#[derive(Clone)]
enum SetupState {
    Idle,
    Running,
    Complete,
    Error(String),
}

struct SetupApp {
    checklist: Vec<(String, bool)>,
    state: Arc<Mutex<SetupState>>,
    progress: Arc<Mutex<f32>>,
    last_output: Arc<Mutex<String>>,
}

impl Default for SetupApp {
    fn default() -> Self {
        Self {
            checklist: CHECKLIST_ITEMS
                .iter()
                .map(|&item| (item.to_string(), false))
                .collect(),
            state: Arc::new(Mutex::new(SetupState::Idle)),
            progress: Arc::new(Mutex::new(0.0)),
            last_output: Arc::new(Mutex::new(String::new())),
        }
    }
}

impl eframe::App for SetupApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let state = self.state.lock().unwrap().clone();
        
        egui::CentralPanel::default().show(ctx, |ui| {
            // Header with logo-style spacing
            ui.add_space(30.0);
            ui.vertical_centered(|ui| {
                ui.heading(egui::RichText::new("Setup Wizard").size(24.0));
            });
            ui.add_space(30.0);
            
            ui.separator();
            ui.add_space(20.0);

            match state {
                SetupState::Idle => {
                    // Checklist section
                    ui.label(egui::RichText::new("Select components to install:").size(14.0));
                    ui.add_space(15.0);
                    
                    for (item, checked) in &mut self.checklist {
                        ui.horizontal(|ui| {
                            ui.add_space(20.0);
                            ui.checkbox(checked, egui::RichText::new(item.as_str()).size(13.0));
                        });
                        ui.add_space(8.0);
                    }

                    ui.add_space(30.0);
                    ui.separator();
                    ui.add_space(20.0);

                    // Install button - centered and styled
                    ui.vertical_centered(|ui| {
                        let button = egui::Button::new(
                            egui::RichText::new("Install").size(16.0)
                        ).min_size(egui::vec2(120.0, 40.0));
                        
                        if ui.add(button).clicked() {
                            self.run_setup(ctx);
                        }
                    });
                }
                
                SetupState::Running => {
                    ui.add_space(20.0);
                    
                    ui.vertical_centered(|ui| {
                        ui.label(egui::RichText::new("Installing...").size(16.0));
                    });
                    
                    ui.add_space(20.0);

                    // Progress bar - styled like classic installers
                    let progress = *self.progress.lock().unwrap();
                    ui.add(
                        egui::ProgressBar::new(progress)
                            .show_percentage()
                            .desired_height(30.0)
                    );

                    ui.add_space(30.0);

                    // Status text - current output
                    ui.add_space(10.0);
                    let output = self.last_output.lock().unwrap().clone();
                    ui.horizontal(|ui| {
                        ui.add_space(10.0);
                        if !output.is_empty() {
                            ui.label(egui::RichText::new(&output).size(12.0).color(egui::Color32::GRAY));
                        } else {
                            ui.label(egui::RichText::new("Please wait...").size(12.0).color(egui::Color32::GRAY));
                        }
                    });
                }
                
                SetupState::Complete => {
                    ui.add_space(40.0);
                    
                    ui.vertical_centered(|ui| {
                        ui.label(egui::RichText::new("✓").size(48.0).color(egui::Color32::GREEN));
                        ui.add_space(15.0);
                        ui.label(egui::RichText::new("Setup completed successfully!").size(16.0));
                    });

                    ui.add_space(30.0);
                    ui.separator();
                    ui.add_space(20.0);

                    ui.vertical_centered(|ui| {
                        let button = egui::Button::new(
                            egui::RichText::new("Finish").size(16.0)
                        ).min_size(egui::vec2(120.0, 40.0));
                        
                        if ui.add(button).clicked() {
                            std::process::exit(0);
                        }
                    });
                    
                    ui.add_space(20.0);
                    
                    // Show current status at bottom
                    let output = self.last_output.lock().unwrap().clone();
                    if !output.is_empty() {
                        ui.horizontal(|ui| {
                            ui.add_space(10.0);
                            ui.label(egui::RichText::new(&output).size(11.0).color(egui::Color32::DARK_GRAY));
                        });
                    }
                }
                
                SetupState::Error(ref error) => {
                    ui.add_space(40.0);
                    
                    ui.vertical_centered(|ui| {
                        ui.label(egui::RichText::new("✗").size(48.0).color(egui::Color32::RED));
                        ui.add_space(15.0);
                        ui.label(egui::RichText::new("Setup failed").size(16.0));
                    });

                    ui.add_space(20.0);

                    ui.group(|ui| {
                        ui.label(egui::RichText::new("Error:").size(12.0).color(egui::Color32::RED));
                        ui.add_space(5.0);
                        ui.label(egui::RichText::new(error).size(11.0));
                    });

                    ui.add_space(30.0);
                    ui.separator();
                    ui.add_space(20.0);

                    ui.vertical_centered(|ui| {
                        let button = egui::Button::new(
                            egui::RichText::new("Close").size(16.0)
                        ).min_size(egui::vec2(120.0, 40.0));
                        
                        if ui.add(button).clicked() {
                            std::process::exit(1);
                        }
                    });
                }
            }

            ui.add_space(20.0);
        });

        // Request repaint for smooth updates
        if matches!(state, SetupState::Running) {
            ctx.request_repaint();
        }
    }
}

impl SetupApp {
    fn run_setup(&mut self, ctx: &egui::Context) {
        *self.state.lock().unwrap() = SetupState::Running;
        *self.progress.lock().unwrap() = 0.0;
        *self.last_output.lock().unwrap() = String::new();

        // Build args with true/false for each checkbox
        let mut args: Vec<String> = self
            .checklist
            .iter()
            .map(|(_, checked)| if *checked { "true" } else { "false" })
            .map(String::from)
            .collect();
        
        // Add custom args
        args.extend(CUSTOM_ARGS.iter().map(|&s| s.to_string()));

        let state = Arc::clone(&self.state);
        let progress = Arc::clone(&self.progress);
        let last_output = Arc::clone(&self.last_output);
        let ctx_clone = ctx.clone();

        // Spawn thread to run the Go script
        thread::spawn(move || {
            // Start progress animation
            let progress_clone = Arc::clone(&progress);
            let state_clone = Arc::clone(&state);
            let ctx_progress = ctx_clone.clone();
            
            thread::spawn(move || {
                let mut current = 0.0;
                loop {
                    thread::sleep(std::time::Duration::from_millis(50));
                    
                    // Check if we're still running
                    if !matches!(*state_clone.lock().unwrap(), SetupState::Running) {
                        break;
                    }
                    
                    // Slow progress that asymptotically approaches 95%
                    current += (0.95 - current) * 0.02;
                    *progress_clone.lock().unwrap() = current;
                    ctx_progress.request_repaint();
                }
            });

            // Get the setup script path
            let script_path = get_setup_script_path();

            // Run the actual command
            let result = Command::new(&script_path)
                .args(&args)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn();

            match result {
                Ok(mut child) => {
                    let mut error_output = String::new();
                    
                    // Read stdout in separate thread
                    let stdout_handle = if let Some(stdout) = child.stdout.take() {
                        let last_output_clone = Arc::clone(&last_output);
                        let ctx_stdout = ctx_clone.clone();
                        Some(thread::spawn(move || {
                            let reader = BufReader::new(stdout);
                            for line in reader.lines() {
                                if let Ok(line) = line {
                                    *last_output_clone.lock().unwrap() = line;
                                    ctx_stdout.request_repaint();
                                }
                            }
                        }))
                    } else {
                        None
                    };
                    
                    // Read stderr
                    if let Some(stderr) = child.stderr.take() {
                        let reader = BufReader::new(stderr);
                        for line in reader.lines() {
                            if let Ok(line) = line {
                                error_output.push_str(&line);
                                error_output.push('\n');
                            }
                        }
                    }
                    
                    // Wait for stdout thread to finish
                    if let Some(handle) = stdout_handle {
                        let _ = handle.join();
                    }
                    
                    let status = child.wait();
                    
                    match status {
                        Ok(exit_status) if exit_status.success() => {
                            *progress.lock().unwrap() = 1.0;
                            *state.lock().unwrap() = SetupState::Complete;
                        }
                        Ok(exit_status) => {
                            let error_msg = if !error_output.is_empty() {
                                format!("Exit code {:?}\n\n{}", exit_status.code(), error_output)
                            } else {
                                format!("Process exited with code: {:?}", exit_status.code())
                            };
                            *state.lock().unwrap() = SetupState::Error(error_msg);
                        }
                        Err(e) => {
                            *state.lock().unwrap() = SetupState::Error(
                                format!("Failed to wait for process: {}", e)
                            );
                        }
                    }
                }
                Err(e) => {
                    *state.lock().unwrap() = SetupState::Error(
                        format!("Failed to start setup script at '{}': {}", script_path, e)
                    );
                }
            }
            
            ctx_clone.request_repaint();
        });
    }
}

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([500.0, 450.0])
            .with_resizable(false),
        ..Default::default()
    };

    eframe::run_native(
        "Setup Wizard",
        options,
        Box::new(|_cc| Ok(Box::new(SetupApp::default()))),
    )
}