(var *config* nil)

(defn getconf [& index] (get-in *config* index))

(defn die [& message]
    (apply eprint "Error: " message)
    (os/exit 1)
)

(defn extract-version [branch]
    (def parts (string/split "-" branch))
    (if (= (parts 0) "saas")
        (string "saas-" (parts 1))
        (parts 0)
    )
)

(defn git [& args]
    (def args (map identity args))
    (array/insert args 0 "git")
    (def code (os/execute (map string args) :p))
    (if (zero? code) false code)
)

(defn current-branch-name []
    (def args ["git" "rev-parse" "--abbrev-ref" "HEAD"])
    (def proc (os/spawn args :p {:out :pipe}))
    (def code (os/proc-wait proc))
    (def branch (string/trim (:read (proc :out) :all)))
    (os/proc-close proc)

    (when (zero? code) branch)
)

(defn git-switch-or-create [target branch]
    (when (git :switch branch)
        (def ver (extract-version branch))
        (git :switch ver)
        (git :pull :--ff-only)
        (git :switch :-c branch)
    )
)

(defn git-switch-soft [target branch]
    (when (git :switch branch)
        (def ver (extract-version branch))
        (when (or (= branch ver) (git :switch ver))
            (die "Can't switch to branch " branch " nor " ver)
        )
    )
)

(defn git-push-with-option [target option]
    (def branch (current-branch-name))
    (if (= branch (extract-version branch))
        (eprint "Warning: Pushing production branch " branch " (ignored)")
        (git :push option (getconf :targets target :dev-remote))
    )
)

(defn git-push-true-force [target] (git-push-with-option target :--force))
(defn git-push-force      [target] (git-push-with-option target :--force-with-lease))
(defn git-pull            [target] (git :pull                   :--ff-only))

(defn git-update [target]
    (def branch (current-branch-name))
    (def ver (extract-version branch))

    (if (= ver branch)
        (git-pull target)
        (do
            (git :fetch "origin" (string ver ":" ver))
            (git :rebase ver)
        )
    )
)

(defn apply-within-path [target function args]
    (def previous-workdir (os/cwd))
    (os/cd (getconf :targets target :path))
    (try
        (apply function target args)
        ([err fib]
            (os/cd previous-workdir)
            (error err)
        )
    )
    (os/cd previous-workdir)
)

(defn dispatch-to-targets [major-fn minor-fn targets & args]
    (each target targets
        (def [generic-target target-fn] (if (<= (chr "A") target (chr "Z"))
            [target major-fn]
            [(+ target (chr "A") (- (chr "a"))) minor-fn]
        ))

        (apply-within-path
            generic-target
            target-fn
            (map identity args)
        )
    )
)

(def +env-args-base+ (do
    (def env @{})

    (defn switch [branch targets]
        (dispatch-to-targets
            git-switch-or-create git-switch-soft
            targets branch
        )
    ) (put env "switch" switch)

    (defn push [targets]
        (dispatch-to-targets
            git-push-true-force git-push-force
            targets
        )
    ) (put env "push" push)

    (defn pull [targets]
        (dispatch-to-targets
            git-pull git-update
            targets
        )
    ) (put env "pull" pull)

    env
))

(defn main [& args]
    (when (< (length args) 2)
        (eprint "Expected at least one argument")
        (eprint)
        (eprint "Possible commands:")
        (eachp [key value] +env-args-base+ (eprint "  " key))
        (os/exit 1)
    )

    (def config-dir (string (os/getenv "HOME") "/.config/odo"))
    (set *config* (eval-string (slurp (string config-dir "/init.janet"))))
    
    (def fn-args (array/slice args 2))
    (apply (+env-args-base+ (args 1)) fn-args)
)
