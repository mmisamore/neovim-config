;; Bootstrap Step 1: Setup Neovim for Tangerine with default settings
;; Bootstrap Step 2: FnlCompile and add
;; dofile(vim.fn.stdpath("config") .. "/" .. "lua/tangerine_vimrc.lua")

(local vim _G.vim)
(local silent {:silent true})

;; "Lazy" Plugin Manager installation
(let [lazy-path   (.. (vim.fn.stdpath "data") "/lazy/lazy.nvim")
      path-found? ((. (or vim.uv vim.loop) "fs_stat") lazy-path)]
  (when (not path-found?)
    (vim.fn.system [
      "git" "clone" "--filter=blob:none" "https://github.com/folke/lazy.nvim.git" "--branch=stable" lazy-path]))
  (vim.opt.rtp:prepend lazy-path))

;; Install Plugins
(local lazy (require :lazy))
(set vim.g.lazy_did_setup false)                  ; Fix a bug where lazy thinks it is re-sourcing even though it isn't
(lazy.setup [
  [:udayvir-singh/tangerine.nvim                  ; Fennel compiler
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
])

;; Easy Align
(set vim.g.easy_align_delimiters { ";" { :pattern ";" } })

;; Install Syntax Plugins
(let [treesitter-config (require :nvim-treesitter.configs)
      ts-setup          (. treesitter-config :setup)]
  (ts-setup {
    :ensure_installed [:bash :c :clojure :dockerfile :fennel :json :lua :python :sql :terraform :yaml]
    :auto_install true
    :highlight {:enable true}}))

;; Setup File Browser
(let [telescope (require :telescope)] (telescope.load_extension :file_browser))

;; Activate Mason for automated Language Server Installation/Config
(local mason (require :mason))
(local mason-lspconfig (require :mason-lspconfig))
(mason.setup)
(mason-lspconfig.setup {
  :ensure_installed [:bashls :jsonls :clangd :dockerls :fennel_ls
                     :lua_ls :sqlls :terraformls :yamlls]
  :automatic_installation true
})

;; Grab cmp-nvim capabilities to use for LSP configuration
(local cmp-nvim-capabilities ((. (require :cmp_nvim_lsp) :default_capabilities)))

;; Launch Language Servers automatically
(local lspconfig (require :lspconfig))
(mason-lspconfig.setup_handlers [
  (fn [server-name]
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
(cmp.setup {
  :snippet {:expand (fn [args] (vim.snippet.expand args.body))}
  :window {
    :completion (cmp.config.window.bordered)
    :documentation (cmp.config.window.bordered)
  }
  :sources (cmp.config.sources [
    {:name :cmdline}
    {:name :buffer}
    {:name :path}
    {:name :nvim_lsp}])
})

;; Use buffer source for "/" and "?"
(cmp.setup.cmdline ["/" "?"] {
  :mapping (cmp.mapping.preset.cmdline)
  :sources [{ :name :buffer }]})

;; Use cmdline and path sources for ":"
(cmp.setup.cmdline ":" {
  :mapping (cmp.mapping.preset.cmdline)
  :sources (cmp.config.sources [ {:name :path} {:name :cmdline}])
  :matching {:disallow_symbol_nonprefix_matching false}})

;; Enable Commenting support
(let [cmt (require :Comment)] (cmt.setup))

;; Code Formatting Setup
(local conform (require :conform))
(conform.setup {
  :formatters_by_ft {
    :c ["clang-format"]
    :clojure ["cljstyle"]
    :fennel ["fnlfmt"]
    :json ["jq"]
    :lua ["stylua"]
    :python ["isort" "black"]
    :sql ["sqlfmt"]
    :terraform ["terraform_fmt"]
    :yaml ["yamlfix"]}})


;; Terminal support

(fn term-bufs []
  "List of terminal buffers"
  (icollect [_ buf (ipairs (vim.api.nvim_list_bufs))]
    (when (= 1 (string.find (vim.api.nvim_buf_get_name buf) "term://"))
      buf)))

(fn first-term-buf [] (. (term-bufs) 1))

(fn open-terminal []
  "Find first terminal buffer (if any), create if necessary, and open window"
  (vim.cmd "below split")
  (let [term-buf (first-term-buf)
        bufh     (if (not= nil term-buf) term-buf
                   (vim.api.nvim_create_buf :true :false))
        winh     (vim.api.nvim_get_current_win)]
    (vim.api.nvim_win_set_buf winh bufh)
    (vim.api.nvim_win_set_height winh 10)
    (vim.api.nvim_set_current_win winh)
    (if (= nil term-buf)
        (do (vim.cmd "terminal") {:buf bufh :win winh})
        {:buf bufh :win winh})))

(fn term-chans []
  "List of terminal channels"
  (let [term-buf   (first-term-buf)
        chans      (vim.api.nvim_list_chans)]
    (icollect [_ c (ipairs chans)]
      (when (= term-buf (. c :buffer))
        (. c :id)))))

(fn first-term-chan [] (. (term-chans) 1))

(fn term-window-id []
  "Id of the window containing the terminal buffer"
  (let [term-buf (first-term-buf)]
    (when term-buf
      (let [id (vim.fn.bufwinid term-buf)]
        (if (= -1 id) nil id)))))

(fn toggle-terminal []
  "Open terminal window (with existing buffer if applicable) if not open,
   otherwise hide the terminal window, keeping the buffer"
  (if (= nil (term-window-id))
    (open-terminal)
    (vim.api.nvim_win_hide (term-window-id))))

(fn send-line-to-term [s]
  "Send a string to the terminal"
  (let [chan (first-term-chan)]
    (vim.api.nvim_chan_send chan s)))

(fn selected-lines []
  "List of visually selected lines"
  (let [first-line (. (vim.fn.getpos "'<") 2)
        last-line  (. (vim.fn.getpos "'>") 2)]
    (vim.fn.getline first-line last-line)))

(fn send-selected-lines-to-term []
  "Prepend a space to each empty visually selected line and send it to the terminal"
  (let [lines     (selected-lines)
        pre-lines (icollect [_ l (ipairs lines)]
                    (if (= "" l)
                        (.. " " l "\n")
                        (.. l "\n")))]
   (each [_ p (ipairs pre-lines)] (send-line-to-term p)))
   (send-line-to-term "\n"))


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
(keymap :t "<Esc>" "<C-\\><C-N>")                                   ; Escape from Terminal insert
(keymap :n "<Leader>t" ":tabnext<Enter>")                           ; Tab navigation
(keymap :n :j :gj)                                                  ; Navigate via displaylines
(keymap :n :k :gk)
(keymap :n "<Leader><space>" ":set hlsearch!<Enter>")               ; Toggle search highlights
(keymap [:n :v] "<Leader>f" (fn [] (conform.format)))               ; Format buffer or selection
(keymap :n "<Leader>sf" ":Telescope find_files<Enter>")             ; Find files by name
(keymap :n "<Leader>sg" ":Telescope live_grep<Enter>")              ; Find files by content
(keymap :n "<Leader>r" #(let [new-name (vim.fn.input "New name: ")] ; Rename a symbol
                          (vim.lsp.buf.rename new-name)))
(keymap :n :gd #(vim.lsp.buf.definition))                           ; Go to Definition
(keymap :n "<Leader>p" ":Telescope file_browser<Enter>")            ; Open File Browser
(keymap [:x :n] :ga "<Plug>(EasyAlign)")                            ; Align
(keymap :n "<Leader>x" toggle-terminal)
(keymap :v "<Leader>e" send-selected-lines-to-term)

;; Global variables
(set vim.g.mapleader ",")                                           ; Fast leader keys
(set vim.g.maplocalleader ",")
(set vim.g.noswapfile true)                                         ; Don't use swap files
(set vim.g.airline_theme :deus)                                     ; Nice status bar colors

;; Options
(macro opt [opt ...]
  `(set ,(sym (.. :vim.o :. opt)) ,...))
(opt :backspace (table.concat [:indent :eol :start] ",")) ; Sane backspacing rules
(opt :termguicolors true)                                 ; Enable 24-bit RBG terminal colors
(opt :clipboard :unnamed)                                 ; Use Mac clipboard
(opt :syntax :on)                                         ; Syntax highlighting
(opt :undofile true)                                      ; Persistent undo
(opt :ignorecase true)                                    ; Smarter searching
(opt :smartcase true)
(opt :guicursor (table.concat [                           ; Use block cursor
  "n-v-c:block-Cursor"
  "i:ver100-iCursor"
  "n-v-c:blinkon0"] ","))
(opt :expandtab true)                                     ; Tabs and spacing
(opt :tabstop 2)
(opt :shiftwidth 2)
(opt :colorcolumn "120")
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
(vim.api.nvim_create_autocmd "BufReadPost" {
  :pattern ["*"]
  :callback (fn []
    (if (and (> (vim.fn.line "'\"") 1)
             (<= (vim.fn.line "'\"") (vim.fn.line "$")))
      (vim.api.nvim_exec "normal! g'\"" false)))})

;; Automatically strip trailing whitespace on save
(vim.api.nvim_create_autocmd "BufWritePre" {
  :pattern ["*"]
  :command "exe 'norm m`' | %s/\\s\\+$//e | norm g``"})
