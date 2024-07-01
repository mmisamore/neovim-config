;; Bootstrap Step 1: Setup Neovim for Tangerine with default settings
;; Bootstrap Step 2: FnlCompile and add
;; dofile(vim.fn.stdpath("config") .. "/" .. "lua/tangerine_vimrc.lua")

(local vim _G.vim)
(local silent {:silent true})

;; "Lazy" Plugin Manager installation
(let [lazy-path   (.. (vim.fn.stdpath "data") "/lazy/lazy.nvim")
      path-found? ((. (or vim.uv vim.loop) "fs_stat") lazy-path)]
  (when (not path-found?)
    (vim.fn.system ["git" "clone" "--filter=blob:none"
                    "https://github.com/folke/lazy.nvim.git"
                    "--branch=stable" lazy-path]))
  (vim.opt.rtp:prepend lazy-path))

;; Install Plugins
(local lazy (require :lazy))
(set vim.g.lazy_did_setup false) ; Fix a bug where lazy thinks it is re-sourcing
                                 ; even though it isn't
(lazy.setup
  [[:udayvir-singh/tangerine.nvim                  ; Fennel compiler
     :tag "v2.8"]
   [:folke/tokyonight.nvim                         ; Modern color scheme
     :tag "v3.0.1"]
   [:vim-airline/vim-airline
     :commit "16c1638"]                            ; Nice status bar
   [:vim-airline/vim-airline-themes                ; Status bar themes
     :commit "a9aa25c"]
   [:tpope/vim-surround
     :commit "3d188ed"]                            ; Surround support
   [:junegunn/vim-easy-align                       ; Align support
     :commit "9815a55"]
   [:nvim-treesitter/nvim-treesitter               ; Better Syntax highlighting
     :tag "v0.9.2"]
   [:nvim-telescope/telescope.nvim                 ; File finding and searching
     :tag "0.1.6"
     :dependencies [:nvim-lua/plenary.nvim]]
   [:nvim-telescope/telescope-file-browser.nvim    ; File browser
     :commit "4d5fd21"
     :dependencies [:nvim-telescope/telescope.nvim ; Patch fonts: brew tap homebrew/cask-fonts
                    :nvim-lua/plenary.nvim]]       ;              brew install font-hack-nerd-font
   [:williamboman/mason.nvim                       ; Manage LSP installations
     :commit "49ff59a"]
   [:williamboman/mason-lspconfig :tag "v1.29.0"]  ; LSP config integration
   [:neovim/nvim-lspconfig                         ; Configure LSPs and autoload them
     :commit "9bda20f"]
   [:hrsh7th/nvim-cmp                              ; LSP-based autocompletion plugin
     :commit "5260e5e"]
   [:hrsh7th/cmp-buffer                            ; Complete via buffer
     :commit "3022dbc"]
   [:hrsh7th/cmp-path                              ; Complete via filesystem paths and folders
     :commit "91ff86c"]
   [:hrsh7th/cmp-cmdline                           ; Complete via vim previous commands
     :commit "d250c63"]
   [:hrsh7th/cmp-nvim-lsp                          ; Complete via LSP
     :commit "39e2eda"]
   [:numToStr/Comment.nvim                         ; Commenting lines
     :commit "0236521"]
   [:stevearc/conform.nvim                         ; Code Formatting
     :commit "00f9d91"]
   [:gpanders/nvim-parinfer                        ; ParInfer for writing in lispy langs
     :commit "5ca0928"]])

;; Easy Align
(set vim.g.easy_align_delimiters { ";" { :pattern ";"}})

;; Install Syntax Plugins
(let [treesitter-config (require :nvim-treesitter.configs)
      ts-setup          (. treesitter-config :setup)]
  (ts-setup
    {:ensure_installed [:bash :c :clojure :dockerfile :fennel :json
                        :lua :python :sql :terraform :yaml]
     :auto_install true
     :highlight {:enable true}}))

;; Setup File Browser
(let [telescope (require :telescope)] (telescope.load_extension :file_browser))

;; Activate Mason for automated Language Server Installation/Config
(local mason (require :mason))
(local mason-lspconfig (require :mason-lspconfig))
(mason.setup)
(mason-lspconfig.setup
  {:ensure_installed [:bashls :clojure_lsp :jsonls :clangd :dockerls :fennel_ls
                      :pylsp :lua_ls :sqlls :terraformls :yamlls]
   :automatic_installation true})

;; Grab cmp-nvim capabilities to use for LSP configuration
(local cmp-nvim-capabilities ((. (require :cmp_nvim_lsp) :default_capabilities)))

;; Launch Language Servers automatically
(local lspconfig (require :lspconfig))
(mason-lspconfig.setup_handlers
  [(fn [server-name]
     (let [server   (. lspconfig server-name)
           setup-fn (. server :setup)]
       (setup-fn {:root_dir vim.loop.cwd
                  :capabilities cmp-nvim-capabilities})))
   ; handlers with customized setups go here
   [:bashls]
   #(let [server   (. lspconfig :bashls)
          setup-fn (. server :setup)]
     (setup-fn {:filetypes [:sh]
                :root_dir vim.loop.cwd
                :capabilities cmp-nvim-capabilities}))])

;; Setup auto-completion
(local cmp (require :cmp))
(cmp.setup
  {:snippet {:expand (fn [args] (vim.snippet.expand args.body))}
   :mapping {"<Tab>" (cmp.mapping.confirm {:select true})}
   :window {:completion (cmp.config.window.bordered)
            :documentation (cmp.config.window.bordered)}
   :sources (cmp.config.sources
              [{:name :cmdline}
               {:name :buffer}
               {:name :path}
               {:name :nvim_lsp}])})

;; Use buffer source for "/" and "?"
(cmp.setup.cmdline ["/" "?"]
  {:mapping (cmp.mapping.preset.cmdline)
   :sources [{ :name :buffer}]})

;; Use cmdline and path sources for ":"
(cmp.setup.cmdline ":"
  {:mapping (cmp.mapping.preset.cmdline)
   :sources (cmp.config.sources [ {:name :path} {:name :cmdline}])
   :matching {:disallow_symbol_nonprefix_matching false}})

;; Enable Commenting support
(let [cmt (require :Comment)] (cmt.setup))

;; Code Formatting Setup
(local conform (require :conform))
(conform.setup
  {:formatters_by_ft {:c ["clang-format"]
                      :clojure ["cljstyle"]
                      :fennel ["fnlfmt"]
                      :json ["jq"]
                      :lua ["stylua"]
                      :python ["isort" "black"]
                      :sql ["sqlfmt"]
                      :terraform ["terraform_fmt"]
                      :yaml ["yamlfix"]}})

;; Terminal support
(fn term-buf-name [...]
  "Get terminal buffer name for the [current] tabpage"
  (let [[tabh]  [...]
        tabpage (or tabh (vim.api.nvim_get_current_tabpage))]
    (.. "terminal-" tabpage)))

(fn substr? [s1 s2]
  "Test if s1 is a substring of s2"
  (if (string.find s2 s1 1 true) true false))

(fn term-buf [...]
  "Get terminal buffer for the [current] tabpage"
  (let [bufs      (vim.api.nvim_list_bufs)
        term-name (term-buf-name ...)]
    (. (icollect [_ b (ipairs bufs)]
         (when (substr? term-name (vim.api.nvim_buf_get_name b)) b)) 1)))

(fn open-terminal []
  "Find terminal buffer for current tabpage (if any), create if necessary,
   and open window"
  (vim.cmd "below split")
  (let [buf  (term-buf)
        bufh (if buf buf (vim.api.nvim_create_buf :true :false))
        winh (vim.api.nvim_get_current_win)]
    (vim.api.nvim_win_set_buf winh bufh)
    (vim.api.nvim_win_set_height winh 10)
    (when (= nil buf)
      (vim.cmd "terminal")
      (vim.api.nvim_buf_set_name bufh (term-buf-name)))
    {:buf bufh :win winh}))

(fn term-chan [...]
  "Terminal channel for terminal buffer for [current] tabpage"
  (let [buf   (term-buf ...)
        chans (vim.api.nvim_list_chans)]
    (when buf
      (. (icollect [_ c (ipairs chans)]
           (when (= buf (. c :buffer)) (. c :id))) 1))))

(fn term-win-id [...]
  "Id of the window in [current] tabpage containing the terminal buffer"
  (let [buf (term-buf ...)]
    (when buf
      (let [id (vim.fn.bufwinid buf)]
        (if (= -1 id) nil id)))))

(fn toggle-term []
  "Open terminal window in current tabpage (with existing buffer if applicable)
  if not open, otherwise hide the terminal window, keeping the buffer"
  (if (= nil (term-win-id))
    (open-terminal)
    (vim.api.nvim_win_hide (term-win-id))))

(fn str-to-term [s]
  "Send a string to the terminal in the current tabpage"
  (let [chan (term-chan)]
    (vim.api.nvim_chan_send chan s)))

(fn selected-region []
  "Get the selected region as a string, possibly with embedded newlines.
   Clobbers the \" register"
  (vim.cmd "noau norm! y:echo")
  (vim.fn.getreg "\""))

(fn str-to-repl []
  "Send selected string (possibly with embedded newlines) to REPL,
   including a trailing newline to force REPL evaluation if necessary.
   Handles janky Python behaviour by assuming ipython and leveraging %paste"
  (let [selection (selected-region)
        filetype  vim.bo.filetype
        suffix    (if (= (string.sub selection -1) "\n") "" "\n")]
    (case filetype
          :python (str-to-term "%paste\n")
          _       (str-to-term (.. selection suffix)))))


;; Keymaps
(fn keymap [mode lhs rhs] (vim.keymap.set mode lhs rhs silent))
(keymap :i :jk :<Esc>)                                              ; Smash escape
(keymap :i :kj :<Esc>)
(keymap :n "<Leader>n" ":set number!<Enter>")                       ; Toggle line numbers
(keymap :v :. ":norm.<Enter>")                                      ; Multi-line repeats
(keymap [:n :v] "<C-h>" "<C-w>h")                                        ; Window navigation
(keymap [:n :v] "<C-j>" "<C-w>j")
(keymap [:n :v] "<C-k>" "<C-w>k")
(keymap [:n :v] "<C-l>" "<C-w>l")
(keymap :t "<C-h>" "<C-\\><C-N><C-w>h")                             ; Navigate away from Terminal windows
(keymap :t "<C-j>" "<C-\\><C-N><C-w>j")
(keymap :t "<C-k>" "<C-\\><C-N><C-w>k")
(keymap :t "<C-l>" "<C-\\><C-N><C-w>l")
(keymap :t "<Esc>" "<C-\\><C-N>")                                    ; Escape from Terminal insert
(keymap :n "<Leader>t" ":tabnext<Enter>")                            ; Tab navigation
(keymap :n :j :gj)                                                   ; Navigate via displaylines
(keymap :n :k :gk)
(keymap :n "<Leader><space>" ":set hlsearch!<Enter>")                ; Toggle search highlights
(keymap [:n :v] "<Leader>f" (fn [] (conform.format)))                ; Format buffer or selection
(keymap :n "K" vim.lsp.buf.hover)
(keymap :n "<Leader>sf" ":Telescope find_files<Enter>")              ; Find files by name
(keymap :n "<Leader>sg" ":Telescope live_grep<Enter>")               ; Find files by content
(keymap :n "<Leader>sp" ":Telescope file_browser<Enter>")            ; Open File Browser
(keymap :n "<Leader>sd" ":Telescope diagnostics<Enter>")
(keymap :n "<Leader>rs" #(let [new-name (vim.fn.input "New name: ")] ; Rename a symbol
                           (vim.lsp.buf.rename new-name)))
(keymap :n :gd vim.lsp.buf.definition)                               ; Go to Definition
(keymap :n :gr vim.lsp.buf.references)                               ; Get references to symbol
(keymap [:x :n] "<Leader>a" "<Plug>(EasyAlign)")                     ; Align
(keymap :n "<Leader>x" toggle-term)                                  ; Toggle terminal window
(keymap :v "<Leader>e" str-to-repl)                                  ; Send selected region to terminal

;; Global variables
(set vim.g.mapleader ",")                                           ; Fast leader keys
(set vim.g.maplocalleader ",")
(set vim.g.airline_theme :deus)                                     ; Nice status bar colors

;; Options
(macro opt [opt ...]
  `(set ,(sym (.. :vim.o :. opt)) ,...))
(opt :swapfile false)                                     ; Disable swapfile
(opt :backspace (table.concat [:indent :eol :start] ",")) ; Sane backspacing rules
(opt :termguicolors true)                                 ; Enable 24-bit RBG terminal colors
(opt :clipboard :unnamed)                                 ; Use Mac clipboard
(opt :syntax :on)                                         ; Syntax highlighting
(opt :undofile true)                                      ; Persistent undo
(opt :ignorecase true)                                    ; Smarter searching
(opt :smartcase true)
(opt :guicursor                                           ; Use block cursor
     (table.concat
       ["n-v-c:block-Cursor" "i:ver100-iCursor"
        "n-v-c:blinkon0"] ","))
(opt :expandtab true)                                     ; Tabs and spacing
(opt :tabstop 2)
(opt :shiftwidth 2)
(opt :colorcolumn "80")
(opt :textwidth 120)
(opt :scrolloff 8)                                        ; Scroll offset
(opt :mouse :a)                                           ; Enable mouse scrolling
(opt :cursorline true)                                    ; Highlight the cursor line
(opt :timeoutlen 500)                                     ; Shorten timeout
(opt :omnifunc "v:lua.vim.lsp.omnifunc")                  ; Enable LSP completion

;; Commands
(vim.cmd.colorscheme "tokyonight-night")                  ; Modern color scheme
(vim.cmd.filetype "plugin indent on")                     ; Ensure filetypes are detected

;; Return to last cursor position when opening
(vim.api.nvim_create_autocmd :BufReadPost
  {:pattern ["*"]
   :callback (fn []
              (if (and (> (vim.fn.line "'\"") 1)
                       (<= (vim.fn.line "'\"") (vim.fn.line "$")))
                (vim.api.nvim_exec "normal! g'\"" false)))})

;; Automatically strip trailing whitespace on save
(vim.api.nvim_create_autocmd :BufWritePre
  {:pattern ["*"]
   :command "exe 'norm m`' | %s/\\s\\+$//e | norm g``"})

;; Proper spacing for Python files
(vim.api.nvim_create_autocmd :FileType
  {:pattern ["python"]
   :callback (fn []
               (set vim.o.tabstop 2)
               (set vim.o.shiftwidth 2))})

