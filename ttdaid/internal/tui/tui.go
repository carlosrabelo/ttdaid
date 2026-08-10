// Package tui implements the Bubble Tea checklist installer.
package tui

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/detector"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/inspect"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/orchestrator"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/runner"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/version"
)

type kind int

const (
	kindGroup kind = iota
	kindComponent
	kindOrphanTitle
)

type listItem struct {
	kind     kind
	id       string // component id or group key
	label    string
	groupKey string
	checked  bool
}

type model struct {
	distro   string
	release  string
	repoRoot string
	items    []listItem
	cursor   int
	status   string
	logLines []string
	logVP    viewport.Model
	width    int
	height   int
	busy     bool
	exitCode int
	quitting bool
	applyCh  <-chan tea.Msg
	// cancelApply aborts the in-flight Apply (kills current script process group).
	cancelApply context.CancelFunc
	// pendingConfirm asks Y/N before Apply when uninstalls are planned.
	pendingConfirm *pendingApply
}

type pendingApply struct {
	dryRun    bool
	desired   map[string]struct{}
	scope     []string
	toInstall []string
	toRemove  []string
}

type detectDoneMsg struct {
	found map[string]bool
}

type applyLogMsg string

type applyStepMsg struct {
	text string
}

type applyDoneMsg struct {
	code int
	msg  string
}

type sudoResultMsg struct {
	ok      bool
	dryRun  bool
	desired map[string]struct{}
	scope   []string
}

type needSudoMsg struct {
	desired map[string]struct{}
	scope   []string
}

var (
	styleTitle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("15")).Background(lipgloss.Color("24"))
	styleStatus  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("11")).Background(lipgloss.Color("24"))
	stylePanel   = lipgloss.NewStyle().Border(lipgloss.ThickBorder()).BorderForeground(lipgloss.Color("37")).Background(lipgloss.Color("18"))
	styleGroup   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("11"))
	styleCursor  = lipgloss.NewStyle().Background(lipgloss.Color("25")).Foreground(lipgloss.Color("15"))
	styleChecked = lipgloss.NewStyle().Foreground(lipgloss.Color("48"))
	styleKeyBar  = lipgloss.NewStyle().Background(lipgloss.Color("37")).Foreground(lipgloss.Color("0"))
	styleKey     = lipgloss.NewStyle().Bold(true).Background(lipgloss.Color("7")).Foreground(lipgloss.Color("0"))
	styleKeyLbl  = lipgloss.NewStyle().Background(lipgloss.Color("37")).Foreground(lipgloss.Color("0"))
)

// Run starts the TUI and returns an exit code.
func Run(distro, release, repoRoot string) int {
	m := newModel(distro, release, repoRoot)
	p := tea.NewProgram(&m, tea.WithAltScreen())
	final, err := p.Run()
	fmt.Println("TTDAID: exited.")
	if err != nil {
		fmt.Fprintf(os.Stderr, "ttdaid tui: %v\n", err)
		return 1
	}
	if mm, ok := final.(*model); ok {
		return mm.exitCode
	}
	return 0
}

type keyAction struct {
	key, label string
}

func (m model) currentKeys() []keyAction {
	if m.pendingConfirm != nil {
		return []keyAction{
			{"Y", "Yes"}, {"N", "No"}, {"Q", "Quit"},
		}
	}
	if m.busy {
		return []keyAction{
			{"X", "Cancel"}, {"PgUp/Dn", "Log"}, {"Ctrl+C", "Force quit"},
		}
	}
	return []keyAction{
		{"D", "Detect"}, {"A", "Apply"}, {"R", "Dry-run"},
		{"I", "Info"}, {"PgUp/Dn", "Log"}, {"Q", "Quit"},
	}
}

func (m model) sideMetrics() (sideW, sideH, scroll int) {
	sideH = m.logVP.Height
	if sideH < 5 {
		sideH = 10
	}
	sideW = 44
	if m.width > 0 && m.width < 80 {
		sideW = max(m.width/2, 28)
	}
	scroll = 0
	if m.cursor >= sideH {
		scroll = m.cursor - sideH + 1
	}
	return sideW, sideH, scroll
}

func newModel(distro, release, repoRoot string) model {
	items, err := buildItems(distro, release, repoRoot)
	vp := viewport.New(40, 10)
	vp.SetContent("")
	status := "Detecting…"
	if err != nil {
		status = "ERROR: " + err.Error()
	} else if len(componentIDsOf(items)) == 0 {
		status = fmt.Sprintf("No components for %s/%s — check --distro/--release", distro, release)
	}
	return model{
		distro:   distro,
		release:  release,
		repoRoot: repoRoot,
		items:    items,
		status:   status,
		logVP:    vp,
		logLines: nil,
	}
}

func buildItems(distro, release, repoRoot string) ([]listItem, error) {
	components, err := catalog.DiscoverComponents(repoRoot, distro, release)
	if err != nil {
		return nil, err
	}
	present := map[string]struct{}{}
	for _, n := range components {
		present[n] = struct{}{}
	}
	items := make([]listItem, 0, len(components)+len(catalog.AllGroups))
	for _, g := range catalog.AllGroups {
		label := catalog.GroupLabels[g]
		if label == "" {
			label = g
		}
		items = append(items, listItem{kind: kindGroup, id: g, label: label, groupKey: g})
		for _, name := range catalog.Groups[g] {
			if _, ok := present[name]; !ok {
				continue
			}
			items = append(items, listItem{
				kind:     kindComponent,
				id:       name,
				label:    catalog.ComponentDisplayName(name, g),
				groupKey: g,
			})
		}
	}
	known := map[string]struct{}{}
	for _, n := range catalog.AllComponents() {
		known[n] = struct{}{}
	}
	orphans := make([]string, 0)
	for _, n := range components {
		if _, ok := known[n]; !ok {
			orphans = append(orphans, n)
		}
	}
	if len(orphans) > 0 {
		items = append(items, listItem{kind: kindOrphanTitle, id: "other", label: "Other"})
		for _, name := range orphans {
			items = append(items, listItem{kind: kindComponent, id: name, label: name})
		}
	}
	return items, nil
}

func componentIDsOf(items []listItem) []string {
	out := make([]string, 0)
	for _, it := range items {
		if it.kind == kindComponent {
			out = append(out, it.id)
		}
	}
	return out
}

func runDetect(names []string) tea.Cmd {
	return func() tea.Msg {
		return detectDoneMsg{found: detector.DetectInstalled(names)}
	}
}

func (m *model) Init() tea.Cmd {
	return runDetect(m.componentIDs())
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.layoutViewports()
		return m, nil

	case detectDoneMsg:
		m.applyDetectResult(msg.found)
		return m, nil

	case applyLogMsg:
		m.appendLog(string(msg))
		return m, waitApply(m.applyCh)

	case applyStepMsg:
		m.status = msg.text
		return m, waitApply(m.applyCh)

	case applyDoneMsg:
		m.busy = false
		m.applyCh = nil
		m.cancelApply = nil
		m.pendingConfirm = nil
		m.exitCode = msg.code
		if msg.code == 0 {
			m.status = msg.msg + " — re-detecting…"
		} else {
			m.status = msg.msg + " — check Output · re-detecting…"
		}
		return m, runDetect(m.componentIDs())

	case needSudoMsg:
		m.status = "sudo: enter password in the terminal…"
		c := exec.Command("sudo", "-v")
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return sudoResultMsg{ok: err == nil, dryRun: false, desired: msg.desired, scope: msg.scope}
		})

	case sudoResultMsg:
		if !msg.ok {
			m.busy = false
			m.status = "sudo auth failed — Apply cancelled"
			return m, nil
		}
		return m.beginApply(msg.desired, msg.scope, msg.dryRun)

	case tea.KeyMsg:
		if m.quitting {
			return m, nil
		}
		return m.handleKey(msg.String())
	}
	return m, nil
}

func (m *model) handleKey(key string) (tea.Model, tea.Cmd) {
	if m.pendingConfirm != nil {
		switch key {
		case "y", "Y":
			p := m.pendingConfirm
			m.pendingConfirm = nil
			return m.proceedApply(p.desired, p.scope, p.dryRun)
		case "n", "N", "esc":
			m.pendingConfirm = nil
			m.status = "Apply cancelled"
			return m, nil
		case "q", "ctrl+c", "ctrl+q":
			m.quitting = true
			return m, tea.Quit
		default:
			return m, nil
		}
	}
	switch key {
	case "x", "X":
		if m.busy && m.cancelApply != nil {
			m.cancelApply()
			m.status = "Cancelling Apply…"
		}
		return m, nil
	case "q", "esc", "ctrl+q":
		if m.busy {
			if m.cancelApply != nil {
				m.cancelApply()
				m.status = "Cancelling Apply… (press Ctrl+C to force quit)"
				return m, nil
			}
			m.status = "Apply running — X cancel · Ctrl+C force quit"
			return m, nil
		}
		m.quitting = true
		return m, tea.Quit
	case "ctrl+c", "Ctrl+C":
		if m.cancelApply != nil {
			m.cancelApply()
		}
		m.quitting = true
		m.busy = false
		return m, tea.Quit
	case "d", "D":
		if !m.busy {
			m.status = "Detecting…"
			return m, runDetect(m.componentIDs())
		}
		return m, nil
	case "i", "I":
		if !m.busy {
			m.showInfo()
		}
		return m, nil
	case "a", "A":
		if !m.busy {
			return m.startApply(false)
		}
		return m, nil
	case "r", "R":
		if !m.busy {
			return m.startApply(true)
		}
		return m, nil
	case "up", "k":
		m.moveCursor(-1)
		return m, nil
	case "down", "j":
		m.moveCursor(1)
		return m, nil
	case " ", "enter":
		if !m.busy {
			m.toggleCursor()
		}
		return m, nil
	case "pgup":
		m.logVP.HalfViewUp()
		return m, nil
	case "pgdown", "PgUp/Dn":
		m.logVP.HalfViewDown()
		return m, nil
	}
	return m, nil
}

func (m *model) layoutViewports() {
	// title+status+keybar ≈ 3; borders
	avail := m.height - 4
	if avail < 6 {
		avail = 6
	}
	sideW := 44
	if m.width < 80 {
		sideW = m.width / 2
	}
	if sideW < 28 {
		sideW = 28
	}
	logW := m.width - sideW - 6
	if logW < 20 {
		logW = 20
	}
	m.logVP.Width = logW
	m.logVP.Height = avail - 2
}

func (m *model) applyDetectResult(found map[string]bool) {
	names := m.componentIDs()
	for i := range m.items {
		if m.items[i].kind != kindComponent {
			continue
		}
		m.items[i].checked = found[m.items[i].id]
	}
	m.syncGroupHeaders()
	wanted := 0
	for _, it := range m.items {
		if it.kind == kindComponent && it.checked {
			wanted++
		}
	}
	m.status = fmt.Sprintf("%d installed · %d total · adjust & A Apply", wanted, len(names))
}

func (m *model) showInfo() {
	if m.cursor < 0 || m.cursor >= len(m.items) {
		m.status = "nothing selected"
		return
	}
	it := m.items[m.cursor]
	m.logLines = nil
	m.logVP.SetContent("")

	switch it.kind {
	case kindGroup:
		var b strings.Builder
		b.WriteString("==> Info: group " + it.label + " (" + it.id + ")\n")
		b.WriteString("Members:\n")
		for _, child := range m.items {
			if child.kind != kindComponent || child.groupKey != it.id {
				continue
			}
			info, err := inspect.Component(m.repoRoot, m.distro, m.release, child.id)
			if err != nil {
				b.WriteString("  • " + child.id + " — " + err.Error() + "\n")
				continue
			}
			summary := summarizeInfo(info)
			b.WriteString("  • " + child.id + " — " + summary + "\n")
		}
		m.setLog(b.String())
		m.status = "info: group " + it.label
	case kindComponent:
		info, err := inspect.Component(m.repoRoot, m.distro, m.release, it.id)
		if err != nil {
			m.setLog(fmt.Sprintf("==> Info: %s\n[ERROR] %v\n", it.id, err))
			m.status = "info failed: " + it.id
			return
		}
		m.setLog(inspect.Format(info))
		m.status = "info: " + it.id
	default:
		m.status = "info: select a component or group"
	}
}

func summarizeInfo(info inspect.Info) string {
	parts := make([]string, 0, 4)
	if n := len(info.AptPackages); n > 0 {
		parts = append(parts, fmt.Sprintf("%d install", n))
	}
	if n := len(info.AptDepends); n > 0 {
		parts = append(parts, fmt.Sprintf("%d depends", n))
	}
	if n := len(info.Flatpaks); n > 0 {
		parts = append(parts, fmt.Sprintf("%d flatpak", n))
	}
	if n := len(info.CurlInstalls); n > 0 {
		parts = append(parts, fmt.Sprintf("%d remote", n))
	}
	if len(parts) == 0 {
		if len(info.Steps) > 0 {
			return info.Steps[0]
		}
		return "custom steps"
	}
	return strings.Join(parts, ", ")
}

func (m *model) setLog(text string) {
	m.logLines = nil
	for _, line := range strings.Split(strings.TrimRight(text, "\n"), "\n") {
		m.logLines = append(m.logLines, line)
	}
	m.logVP.SetContent(strings.Join(m.logLines, "\n"))
	m.logVP.GotoTop()
}

func (m model) componentIDs() []string {
	out := make([]string, 0)
	for _, it := range m.items {
		if it.kind == kindComponent {
			out = append(out, it.id)
		}
	}
	return out
}

func (m model) selectedDesired() map[string]struct{} {
	out := map[string]struct{}{}
	for _, it := range m.items {
		if it.kind == kindComponent && it.checked {
			out[it.id] = struct{}{}
		}
	}
	return out
}

func (m *model) syncGroupHeaders() {
	for i, it := range m.items {
		if it.kind != kindGroup {
			continue
		}
		total, selected := 0, 0
		for _, child := range m.items {
			if child.kind == kindComponent && child.groupKey == it.id {
				total++
				if child.checked {
					selected++
				}
			}
		}
		m.items[i].checked = total > 0 && selected == total
	}
}

func (m *model) moveCursor(delta int) {
	if len(m.items) == 0 {
		return
	}
	m.cursor += delta
	if m.cursor < 0 {
		m.cursor = 0
	}
	if m.cursor >= len(m.items) {
		m.cursor = len(m.items) - 1
	}
}

func (m *model) toggleCursor() {
	if m.cursor < 0 || m.cursor >= len(m.items) {
		return
	}
	it := &m.items[m.cursor]
	switch it.kind {
	case kindGroup:
		it.checked = !it.checked
		for i := range m.items {
			if m.items[i].kind == kindComponent && m.items[i].groupKey == it.id {
				m.items[i].checked = it.checked
			}
		}
		m.status = fmt.Sprintf("%s: %d selected", it.label, len(m.selectedDesired()))
	case kindComponent:
		it.checked = !it.checked
		m.syncGroupHeaders()
		m.status = fmt.Sprintf("%d selected", len(m.selectedDesired()))
	}
}

func (m *model) startApply(dryRun bool) (tea.Model, tea.Cmd) {
	desired := m.selectedDesired()
	scope := m.componentIDs()
	actions := orchestrator.PlanActions(desired, scope)
	toInstall, toRemove := orchestrator.SplitActions(actions)

	// Real Apply that would uninstall: require explicit confirmation.
	if !dryRun && len(toRemove) > 0 {
		m.pendingConfirm = &pendingApply{
			dryRun:    false,
			desired:   desired,
			scope:     scope,
			toInstall: toInstall,
			toRemove:  toRemove,
		}
		var b strings.Builder
		b.WriteString("==> Confirm Apply\n")
		b.WriteString(fmt.Sprintf("Install   (%d): %s\n", len(toInstall), orNone(toInstall)))
		b.WriteString(fmt.Sprintf("Uninstall (%d): %s\n", len(toRemove), orNone(toRemove)))
		b.WriteString("\nPress Y to confirm, N to cancel.\n")
		m.setLog(b.String())
		m.status = fmt.Sprintf("Confirm: +%d install · -%d uninstall — Y yes · N cancel",
			len(toInstall), len(toRemove))
		return m, nil
	}

	return m.proceedApply(desired, scope, dryRun)
}

func (m *model) proceedApply(desired map[string]struct{}, scope []string, dryRun bool) (tea.Model, tea.Cmd) {
	m.busy = true
	m.pendingConfirm = nil
	m.logLines = nil
	m.logVP.SetContent("")
	mode := "apply"
	if dryRun {
		mode = "dry-run"
	}
	m.status = mode + "…"
	if dryRun {
		return m.beginApply(desired, scope, true)
	}
	return m, ensureSudoCmd(desired, scope)
}

func orNone(items []string) string {
	if len(items) == 0 {
		return "(none)"
	}
	return strings.Join(items, " ")
}

func ensureSudoCmd(desired map[string]struct{}, scope []string) tea.Cmd {
	return func() tea.Msg {
		if os.Geteuid() == 0 {
			return sudoResultMsg{ok: true, dryRun: false, desired: desired, scope: scope}
		}
		if exec.Command("sudo", "-n", "true").Run() == nil {
			return sudoResultMsg{ok: true, dryRun: false, desired: desired, scope: scope}
		}
		return needSudoMsg{desired: desired, scope: scope}
	}
}

func (m *model) beginApply(desired map[string]struct{}, scope []string, dryRun bool) (tea.Model, tea.Cmd) {
	ch := make(chan tea.Msg, 64)
	ctx, cancel := context.WithCancel(context.Background())
	m.cancelApply = cancel
	repoRoot := m.repoRoot
	distro := m.distro
	release := m.release
	go func() {
		defer cancel()
		emit := func(line string) {
			ch <- applyLogMsg(line)
		}
		onStep := func(name, action string, index, total int) {
			ch <- applyStepMsg{text: fmt.Sprintf("[%d/%d] %s %s", index, total, action, name)}
		}
		opts := orchestrator.ApplyOptions{
			Distro:      distro,
			Release:     release,
			Desired:     desired,
			Scope:       scope,
			DryRun:      dryRun,
			SkipOSCheck: dryRun,
			RepoRoot:    repoRoot,
			UseSudo:     !dryRun,
			Ctx:         ctx,
		}
		code := orchestrator.Apply(opts, emit, onStep)
		msg := "done"
		switch {
		case code == runner.ExitCancelled:
			msg = "cancelled"
		case code != 0:
			msg = fmt.Sprintf("finished with errors (exit %d)", code)
		}
		ch <- applyDoneMsg{code: code, msg: msg}
	}()
	m.applyCh = ch
	return m, waitApply(ch)
}

func waitApply(ch <-chan tea.Msg) tea.Cmd {
	if ch == nil {
		return nil
	}
	return func() tea.Msg {
		msg, ok := <-ch
		if !ok {
			return applyDoneMsg{code: 1, msg: "apply channel closed"}
		}
		return msg
	}
}

func (m *model) appendLog(line string) {
	line = strings.TrimRight(line, "\n")
	if line == "" {
		return
	}
	m.logLines = append(m.logLines, line)
	if len(m.logLines) > 2000 {
		m.logLines = m.logLines[len(m.logLines)-2000:]
	}
	m.logVP.SetContent(strings.Join(m.logLines, "\n"))
	m.logVP.GotoBottom()
}

func (m *model) View() string {
	if m.quitting {
		return ""
	}
	title := styleTitle.Render(fmt.Sprintf(" TTDAID %s ", version.Version)) +
		lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("11")).Background(lipgloss.Color("23")).
			Render(fmt.Sprintf(" %s/%s ", m.distro, m.release)) +
		lipgloss.NewStyle().Foreground(lipgloss.Color("14")).
			Render("  * = keep/install")

	status := styleStatus.Width(max(m.width, 40)).Render(" " + m.status + " ")

	sideLines := make([]string, 0, len(m.items))
	for i, it := range m.items {
		mark := " "
		if it.checked {
			mark = "*"
		}
		var line string
		switch it.kind {
		case kindGroup, kindOrphanTitle:
			line = styleGroup.Render(fmt.Sprintf("[%s] %s", mark, it.label))
		default:
			body := fmt.Sprintf("[%s] %s", mark, it.label)
			if it.checked {
				body = styleChecked.Render(body)
			}
			line = body
		}
		if i == m.cursor {
			line = styleCursor.Render(line)
		}
		sideLines = append(sideLines, line)
	}
	sideW, sideH, start := m.sideMetrics()
	end := start + sideH
	if end > len(sideLines) {
		end = len(sideLines)
	}
	visible := strings.Join(sideLines[start:end], "\n")

	sidebar := stylePanel.Width(sideW).Height(sideH + 2).Render(
		lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("11")).Render(" Components ") + "\n" + visible,
	)
	logPane := stylePanel.Width(max(m.width-sideW-4, 24)).Height(sideH + 2).Render(
		lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("11")).Render(" Output ") + "\n" + m.logVP.View(),
	)
	main := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, " ", logPane)

	var keyParts []string
	for _, k := range m.currentKeys() {
		// Separate key chip from label so "D"+"Detect" does not read as "DDetect".
		keyParts = append(keyParts,
			styleKey.Render(" "+k.key+" ")+styleKeyLbl.Render(" "+k.label+" "))
	}
	keybar := styleKeyBar.Width(max(m.width, 40)).Render(strings.Join(keyParts, ""))

	return title + "\n" + status + "\n" + main + "\n" + keybar
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
