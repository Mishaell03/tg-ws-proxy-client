#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Uniquely identifies this app across the whole system. Use something
// specific enough not to collide with other software (e.g. a GUID or your
// reverse-domain identifier).
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\com_github_yourname_tgwsproxy_singleinstance";

constexpr wchar_t kMainWindowTitle[] = L"tg_proxy";

// Brings an already-running instance's window to the foreground. Restores
// it first if it was minimized.
void ActivateExistingInstance() {
  HWND existing = ::FindWindowW(nullptr, kMainWindowTitle);
  if (existing == nullptr) {
    return;
  }

  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  }
  ::SetForegroundWindow(existing);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Enforce a single running instance. If the mutex already exists, another
  // instance owns it — hand off focus to it and exit immediately without
  // touching the job object, console, or COM.
  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  const bool already_running =
      single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS;

  if (already_running) {
    ActivateExistingInstance();
    if (single_instance_mutex != nullptr) {
      ::CloseHandle(single_instance_mutex);
    }
    return EXIT_SUCCESS;
  }

  // Keep desktop helper processes tied to the application lifetime. Python
  // inherits this job, and Windows terminates it if the UI process closes or
  // crashes, preventing an orphaned proxy from retaining the listen port.
  HANDLE process_job = ::CreateJobObjectW(nullptr, nullptr);
  if (process_job != nullptr) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {};
    limits.BasicLimitInformation.LimitFlags =
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!::SetInformationJobObject(process_job,
                                   JobObjectExtendedLimitInformation, &limits,
                                   sizeof(limits)) ||
        !::AssignProcessToJobObject(process_job, ::GetCurrentProcess())) {
      ::CloseHandle(process_job);
      process_job = nullptr;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kMainWindowTitle, origin, size)) {
    if (single_instance_mutex != nullptr) {
      ::ReleaseMutex(single_instance_mutex);
      ::CloseHandle(single_instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (process_job != nullptr) {
    ::CloseHandle(process_job);
  }
  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}