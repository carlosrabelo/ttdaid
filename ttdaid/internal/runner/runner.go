// Package runner executes component bash scripts with streamed output.
package runner

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
)

// ExitCancelled is returned when a run is aborted via context cancel.
const ExitCancelled = 130

// LogFn receives output lines (may include trailing newline).
type LogFn func(line string)

func defaultLog(line string) {
	if !strings.HasSuffix(line, "\n") {
		line += "\n"
	}
	fmt.Fprint(os.Stdout, line)
}

// ComponentScript returns the path to distros/<distro>/<release>/scripts/<name>.sh.
func ComponentScript(repoRoot, distro, release, name string) string {
	return filepath.Join(catalog.ScriptsDir(repoRoot, distro, release), name+".sh")
}

func detectMainUser() (string, string) {
	if os.Geteuid() == 0 {
		u := os.Getenv("SUDO_USER")
		if u == "" {
			u = "root"
		}
		home := "/root"
		if u != "root" {
			home = filepath.Join("/home", u)
		}
		if pu, err := user.Lookup(u); err == nil && pu.HomeDir != "" {
			home = pu.HomeDir
		}
		return u, home
	}
	u := os.Getenv("USER")
	if u == "" {
		if cu, err := user.Current(); err == nil {
			u = cu.Username
		}
	}
	home := os.Getenv("HOME")
	if pu, err := user.Lookup(u); err == nil && pu.HomeDir != "" {
		home = pu.HomeDir
	}
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	return u, home
}

func detectWSL() bool {
	data, err := os.ReadFile("/proc/version")
	if err == nil {
		low := strings.ToLower(string(data))
		if strings.Contains(low, "microsoft") || strings.Contains(low, "wsl") {
			return true
		}
	}
	_, err = os.Stat("/usr/bin/wslpath")
	return err == nil
}

func detectSystemd() bool {
	st, err := os.Stat("/run/systemd/system")
	return err == nil && st.IsDir()
}

func componentEnv(dryRun bool) []string {
	env := os.Environ()
	set := func(k, v string) {
		prefix := k + "="
		for i, e := range env {
			if strings.HasPrefix(e, prefix) {
				env[i] = prefix + v
				return
			}
		}
		env = append(env, prefix+v)
	}
	if dryRun {
		set("DRY_RUN", "true")
	} else {
		set("DRY_RUN", "false")
	}
	mu, mh := detectMainUser()
	set("MAIN_USER", mu)
	set("MAIN_HOME", mh)
	if detectWSL() {
		set("IS_WSL", "true")
	} else {
		set("IS_WSL", "false")
	}
	if detectSystemd() {
		set("HAS_SYSTEMD", "true")
	} else {
		set("HAS_SYSTEMD", "false")
	}
	set("NO_COLOR", "1")
	set("DEBIAN_FRONTEND", "noninteractive")
	set("APT_LISTCHANGES_FRONTEND", "none")
	return env
}

func killProcessGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	pid := cmd.Process.Pid
	_ = syscall.Kill(-pid, syscall.SIGTERM)
	time.AfterFunc(2*time.Second, func() {
		_ = syscall.Kill(-pid, syscall.SIGKILL)
	})
}

func streamCmd(ctx context.Context, cmd *exec.Cmd, emit LogFn) int {
	if ctx == nil {
		ctx = context.Background()
	}
	cmd.Stdin = nil
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		emit(fmt.Sprintf("[ERROR] %v\n", err))
		return 1
	}
	cmd.Stderr = cmd.Stdout
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		emit(fmt.Sprintf("[ERROR] %v\n", err))
		return 1
	}

	readDone := make(chan struct{})
	go func() {
		defer close(readDone)
		reader := bufio.NewReader(stdout)
		var buf bytes.Buffer
		tmp := make([]byte, 256)
		for {
			n, err := reader.Read(tmp)
			if n > 0 {
				buf.Write(tmp[:n])
				for {
					data := buf.Bytes()
					nIdx := bytes.IndexByte(data, '\n')
					rIdx := bytes.IndexByte(data, '\r')
					if nIdx < 0 && rIdx < 0 {
						break
					}
					if nIdx < 0 || (rIdx >= 0 && rIdx < nIdx) {
						line := string(data[:rIdx])
						buf.Next(rIdx + 1)
						if line != "" {
							emit(line + "\n")
						}
					} else {
						line := string(data[:nIdx+1])
						buf.Next(nIdx + 1)
						emit(line)
					}
				}
			}
			if err == io.EOF {
				break
			}
			if err != nil {
				break
			}
		}
		if buf.Len() > 0 {
			s := buf.String()
			if !strings.HasSuffix(s, "\n") {
				s += "\n"
			}
			emit(s)
		}
	}()

	waitCh := make(chan error, 1)
	go func() {
		<-readDone
		waitCh <- cmd.Wait()
	}()

	select {
	case <-ctx.Done():
		killProcessGroup(cmd)
		<-waitCh
		emit("[WARN] Command cancelled\n")
		return ExitCancelled
	case err := <-waitCh:
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				return ee.ExitCode()
			}
			return 1
		}
		return 0
	}
}

// RunComponent executes bash <component>.sh install|uninstall.
func RunComponent(ctx context.Context, repoRoot, distro, release, name, action string, dryRun, useSudo bool, log LogFn) int {
	if action != "install" && action != "uninstall" {
		if log == nil {
			log = defaultLog
		}
		log(fmt.Sprintf("[ERROR] Invalid action: %s\n", action))
		return 1
	}
	emit := log
	if emit == nil {
		emit = defaultLog
	}
	if ctx == nil {
		ctx = context.Background()
	}
	if err := ctx.Err(); err != nil {
		emit("[WARN] Cancelled before start\n")
		return ExitCancelled
	}
	script := ComponentScript(repoRoot, distro, release, name)
	if st, err := os.Stat(script); err != nil || st.IsDir() {
		emit(fmt.Sprintf("[ERROR] Script not found: %s\n", script))
		return 1
	}
	env := componentEnv(dryRun)
	preserve := "DRY_RUN,MAIN_USER,MAIN_HOME,IS_WSL,HAS_SYSTEMD,NO_COLOR,DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND"
	var args []string
	if useSudo && os.Geteuid() != 0 {
		args = append(args, "sudo", "-n", "--preserve-env="+preserve, "bash", script, action)
	} else {
		args = append(args, "bash", script, action)
	}
	emit(fmt.Sprintf("\n==> Running: %s %s\n", filepath.Base(script), action))
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Env = env
	code := streamCmd(ctx, cmd, emit)
	if code != 0 && code != ExitCancelled && useSudo && os.Geteuid() != 0 {
		emit("[ERROR] Command failed. If sudo asked for a password, run " +
			"`sudo -v` in another terminal (or enable the system-sudoers component), " +
			"then retry Apply.\n")
	}
	return code
}

// AptUpdate refreshes the APT cache (or dry-runs).
func AptUpdate(ctx context.Context, dryRun, useSudo bool, log LogFn) int {
	emit := log
	if emit == nil {
		emit = defaultLog
	}
	if ctx == nil {
		ctx = context.Background()
	}
	if err := ctx.Err(); err != nil {
		emit("[WARN] Cancelled before apt update\n")
		return ExitCancelled
	}
	if dryRun {
		emit("[DRY-RUN] apt-get update\n")
		return 0
	}
	var args []string
	if useSudo && os.Geteuid() != 0 {
		args = append(args, "sudo", "-n", "apt-get", "update", "-q")
	} else {
		args = append(args, "apt-get", "update", "-q")
	}
	emit("\n==> Updating APT cache\n")
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Env = componentEnv(false)
	code := streamCmd(ctx, cmd, emit)
	if code != 0 && code != ExitCancelled && useSudo && os.Geteuid() != 0 {
		emit("[ERROR] apt update failed. If sudo needs a password, run `sudo -v` then retry Apply.\n")
	}
	return code
}
