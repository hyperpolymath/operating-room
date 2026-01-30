;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for system-operating-theatre

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2024-06-01")
    (updated "2025-01-17")
    (project "system-operating-theatre")
    (repo "hyperpolymath/system-operating-theatre"))

  (project-context
    (name "System Operating Theatre")
    (tagline "Plan-first system management and hardening tool")
    (tech-stack ("d" "bash")))

  (current-position
    (phase "alpha")
    (overall-completion 60)
    (working-features
      ("sor CLI"
       "scan→plan→apply→undo→receipt workflow"
       "Health checks"
       "Security hardening"))))
