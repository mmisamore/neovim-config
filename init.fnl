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
  :udayvir-singh/tangerine.nvim                   ; Fennel compiler
  :folke/tokyonight.nvim                          ; Modern color scheme
  :vim-airline/vim-airline                        ; Nice status bar
  :vim-airline/vim-airline-themes                 ; Status bar themes
  :tpope/vim-surround                             ; Surround support
  :junegunn/vim-easy-align                        ; Align support
  :nvim-treesitter/nvim-treesitter                ; Better Syntax highlighting
  [:nvim-telescope/telescope.nvim                 ; File finding and searching
    :tag "0.1.6"
    :dependencies [:nvim-lua/plenary.nvim]]
  [:nvim-telescope/telescope-file-browser.nvim    ; File browser
    :dependencies [:nvim-telescope/telescope.nvim ; Patch fonts: brew tap homebrew/cask-fonts
                   :nvim-lua/plenary.nvim]]       ;              brew install font-hack-nerd-font
  :williamboman/mason.nvim                        ; Manage LSP installations
  :williamboman/mason-lspconfig                   ; LSP config integration
  :neovim/nvim-lspconfig                          ; Configure LSPs and autoload them
  :hrsh7th/nvim-cmp                               ; LSP-based autocompletion plugin
  :hrsh7th/cmp-buffer                             ; Complete via buffer
  :hrsh7th/cmp-path                               ; Complete via filesystem paths and folders
  :hrsh7th/cmp-cmdline                            ; Complete via vim previous commands
  :hrsh7th/cmp-nvim-lsp                           ; Complete via LSP
  :numToStr/Comment.nvim                          ; Commenting lines
  :stevearc/conform.nvim                          ; Code Formatting
  :akinsho/toggleterm.nvim                        ; Terminal support
])

;; Alignment
(set vim.g.easy_align_delimiters {";" { :pattern ";" }})

;; Install Syntax Plugins
(let [treesitter-config (require :nvim-treesitter.configs)
      ts-setup          (. treesitter-config :setup)]
  (ts-setup {
    :ensure_installed [:bash :c :clojure :dockerfile :fennel :json :lua :python :sql :terraform :yaml]
    :auto_install true
    :highlight {:enable true}}))

;; Setup File Browser
(local telescope (require :telescope))
(telescope.load_extension :file_browser)

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
      (setup-fn {:root_dir vim.loop.cwd :filetypes [:sh]
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
(local cmt (require :Comment))
(cmt.setup)

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

;; Terminal setup. From a Terminal we can invoke whichever REPL we want
(local toggleterm (require :toggleterm))
(toggleterm.setup {
  :size 10
  :open_mapping "<Leader>x"
  :direction "horizontal"
})

;; Keymaps
(fn keymap [mode lhs rhs] (vim.keymap.set mode lhs rhs silent))
(keymap :i :jk :<Esc>)                                              ; Smash escape
(keymap :i :kj :<Esc>)
(keymap :n "<Leader>n" ":set number!<Enter>")                       ; Toggle line numbers
(keymap :v :. ":norm.<Enter>")                                      ; Multi-line repeats
(keymap :n "<C-h>" "<C-w>h")                                        ; Window navigation
(keymap :n "<C-j>" "<C-w>j")
(keymap :n "<C-k>" "<C-w>k")
(keymap :n "<C-l>" "<C-w>l")
(keymap :n "<Leader>t" ":tabnext<Enter>")                           ; Tab navigation
(keymap :n :j :gj)                                                  ; Navigate via displaylines
(keymap :n :k :gk)
(keymap :n "<Leader><space>" ":set hlsearch!<Enter>")               ; Toggle search highlights
(keymap :n "<Leader>u" ":set cuc!<Enter>")                          ; Toggle column highlight
(keymap [:n :v] "<Leader>f" (fn [] (conform.format)))               ; Format buffer or selection
(keymap :n "<Leader>s" ":Telescope find_files<Enter>")              ; Find files by name
(keymap :n "<Leader>g" ":Telescope live_grep<Enter>")               ; Find files by content
(keymap :n "<Leader>r" #(let [new-name (vim.fn.input "New name: ")] ; Rename a symbol
                          (vim.lsp.buf.rename new-name)))
(keymap :n "<Leader>p" ":Telescope file_browser<Enter>")            ; Open File Browser
(keymap [:x :n] :ga "<Plug>(EasyAlign)")                            ; Align
(keymap :v "<Leader>e" ":ToggleTermSendVisualLines<Enter>")         ; Send Selection to terminal
(keymap :t "<Esc>" "<C-\\><C-n>")                                   ; Escape from Terminal insert

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
(opt :colorcolumn 120)
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
