# tmux-cpu-mem-minibars

CPU and RAM as colored mini-bars on the tmux status line. One small POSIX shell script, no plugin manager, no dependencies.

```
CPU █░░░░░░░  13%  RAM ███░░░░░ 5.7/15.6G | 10:39
```

- **CPU** is the usage *since the previous refresh* (read from `/proc/stat`), not the average since boot.
- **RAM** is `MemTotal - MemAvailable`, the same figure `free -h` and `htop` show as "used" (disk cache not counted), as used/total in GiB.
- Bars turn **green** below 50 %, **yellow** from 50 to 80 %, **red** above. It is meant for spotting at a glance that something is off on a remote machine.

Linux only (it reads `/proc`). Works with any tmux that supports `#(...)` in the status line.

## Install

1. Put the script somewhere and make it executable:

   ```sh
   mkdir -p ~/bin
   cp tmux-cpu-mem-minibars.sh ~/bin/
   chmod +x ~/bin/tmux-cpu-mem-minibars.sh
   ```

2. Add this to `~/.tmux.conf` (see [`tmux.conf.example`](tmux.conf.example)). **Use an absolute path** for the script:

   ```tmux
   set -g status-interval 2
   set -g status-style 'bg=colour235,fg=colour250'
   set -g status-right-length 100
   set -g status-right '#(/home/YOUR_USER/bin/tmux-cpu-mem-minibars.sh) #[default]| %H:%M'
   ```

3. Restart the tmux server so the file is read again: `tmux kill-server`, then `tmux`.
   (Or, inside tmux: `tmux source-file ~/.tmux.conf`.)

## Customize

Everything is in the script, a few lines each:

- **Thresholds**: edit `50` and `80` in the `col()` function.
- **Bar width**: the `8` in `bar()` (`$1*8/100` and `-lt 8`).
- **Characters**: replace `█` and `░` with `=` and `-` if you want plain ASCII.
- **Refresh rate**: `status-interval` in the tmux config.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Nothing appears, but the time does | The text is green on tmux's default **green** status bar, so it is invisible | Set a dark `status-style`, as in step 2 |
| Nothing appears at all | Wrong or relative path (`~`, `$HOME` and typos fail silently) | Use the full absolute path; test with `/path/to/tmux-cpu-mem-minibars.sh` in a shell |
| Config seems ignored | An already running tmux server does not re-read the file | `tmux kill-server`, then start tmux again |
| `#[fg=green]CPU ...` printed in a plain shell | Normal: those are tmux style codes | They are only interpreted inside tmux |
| CPU shows `0%` at first | The first call has nothing to compare with | It is correct from the second refresh |
| Strange characters instead of bars | Terminal or locale is not UTF-8 | Use a UTF-8 locale, or switch to the ASCII characters above |

To check that tmux really runs the script and see any error:

```sh
tmux set -g status-right '#(/home/YOUR_USER/bin/tmux-cpu-mem-minibars.sh 2>/tmp/stats.err | tee /tmp/stats.out) | %H:%M'
sleep 5; cat /tmp/stats.out /tmp/stats.err
```

## How it works

On each refresh tmux runs the script. It reads the aggregate `cpu` line of `/proc/stat`, compares it with the totals saved by the previous call in `/tmp/.tmux-cpu-mem-minibars-cpu-<uid>`, and derives the busy percentage from the difference. RAM comes from `/proc/meminfo`. The output is a single line with tmux style codes (`#[fg=...]`).

## License

MIT, see [LICENSE](LICENSE).
