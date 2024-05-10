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
(set vim.g.lazy_did_setup false)   ; Fix a bug where lazy thinks it is re-sourcing even though it isn't
(lazy.setup [
  :udayvir-singh/tangerine.nvim    ; Fennel compiler
  :vim-airline/vim-airline         ; Nice status bar
  :bluz71/vim-nightfly-guicolors   ; Modern color scheme
  :tpope/vim-surround              ; Surround support
  :nvim-treesitter/nvim-treesitter ; Better Syntax highlighting
  [:nvim-telescope/telescope.nvim  ; File finding and searching
    :tag "0.1.6"
    :dependencies [:nvim-lua/plenary.nvim]]
  :williamboman/mason.nvim         ; Manage LSP installations
  :williamboman/mason-lspconfig    ; LSP config integration
  :neovim/nvim-lspconfig           ; Configure LSPs and autoload them
  :hrsh7th/nvim-cmp                ; LSP-based autocompletion plugin
  :hrsh7th/cmp-buffer              ; Complete via buffer
  :hrsh7th/cmp-path                ; Complete via filesystem paths and folders
  :hrsh7th/cmp-cmdline             ; Complete via vim previous commands
  :hrsh7th/cmp-nvim-lsp            ; Complete via LSP
  :numToStr/Comment.nvim           ; Commenting lines
  :Olical/conjure                  ; Conjure for Clojure, Fennel, etc.
  :PaterJason/cmp-conjure          ; Complete via Conjure
])

;; Install Syntax Plugins
(let [treesitter-config (require :nvim-treesitter.configs)
      ts-setup          (. treesitter-config :setup)]
  (ts-setup {
    :ensure_installed [:bash :json :c :dockerfile :fennel :lua :sql :terraform :yaml]
    :auto_install true}))

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
    {:name :nvim_lsp}
    {:name :conjure}])
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

;; Keymaps
(local keymap vim.keymap.set)
(keymap :i :jk :<Esc> silent)                                      ; Smash escape
(keymap :i :kj :<Esc> silent)
(keymap :n "<Leader>n" ":set number!<Enter>" silent)               ; Toggle line numbers
(keymap :v :. ":norm.<Enter>" silent)                              ; Multi-line repeats
(keymap :n "<C-h>" "<C-w>h" silent)                                ; Window navigation
(keymap :n "<C-j>" "<C-w>j" silent)
(keymap :n "<C-k>" "<C-w>k" silent)
(keymap :n "<C-l>" "<C-w>l" silent)
(keymap :n "<Leader>t" ":tabnext<Enter>" silent)                   ; Tab navigation
(keymap :n :j :gj silent)                                          ; Navigate via displaylines
(keymap :n :k :gk silent)
(keymap :n "<Leader><space>" ":set hlsearch!<Enter>" silent)       ; Toggle search highlights
(keymap :n "<Leader>u" ":set cuc!<Enter>" silent)                  ; Toggle column highlight
(keymap :n "<Leader>f" ":lua= vim.lsp.buf.format()<Enter>" silent) ; Format buffer using LSP
(keymap :n "<Leader>s" ":Telescope find_files<Enter>")
(keymap :n "<Leader>g" ":Telescope live_grep<Enter>")

;; Global variables
(set vim.g.mapleader ",")                                         ; Fast leader keys
(set vim.g.maplocalleader ",")
(set vim.g.noswapfile true)                                       ; Don't use swap files
(set vim.g.conjure#filetype#fennel "conjure.client.fennel.stdio") ; Don't use Aniseed for Fennel

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
(vim.cmd "colorscheme nightfly")                          ; Modern color scheme
(vim.cmd "filetype plugin indent on")                     ; Ensure filetypes are detected

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
