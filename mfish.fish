#!/usr/bin/env fish

# =============================================================================
# mfish - A plugin for managing email workflows with mblaze and Fish shell
#
# Copyright (C) 2025 Xavier Maillard <x@maillard.im>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# =============================================================================

# Fonction interne pour récupérer une variable dans $MBLAZE/profile
function __mfish_get_profile_var
    set -l var_name $argv[1]
    set -l profile_file "$MBLAZE/profile"

    if test -f $profile_file
        mhdr -h $var_name $profile_file 2>/dev/null
    else
        echo ""
    end
end

# Main function
function mfish
    set -l prompt_default "mfish"
    set -l maildir_default "~/mail/Reception"
    set -l maildir $maildir_default
    set -l profile_file "$MBLAZE/profile"

    switch $argv[1]
        case -q
            mfish_prompt $maildir
        case -1
            set -e argv[1]
	         if test (count $argv) -gt 0
   
                switch $argv[1]
                    case fetch
                        mfish_fetch $argv[2..-1]
                    case index
                        mfish_index
                    case ls
                        mfish_ls $argv[2..-1]
                    case cd
                        mfish_cd $argv[2..-1]
                    case show
                        mfish_show $argv[2..-1]
                    case grep
                        mfish_grep $argv[2..-1]
                    case rm
                        mfish_rm $argv[2..-1]
                    case spam
                        mfish_spam $argv[2..-1]
                    case help
                        mfish_help
                    case '*'
                        echo "Unknown command: $argv[1]. Type 'help' for a list of commands."
                end
            else
                echo "Error: No command provided."
                return 1
            end
	case fetch
		mfish_fetch $argv[2..-1]
        case '*'
            if tmux has-session -t mfish 2>/dev/null
                tmux attach -t mfish
            else
                tmux new-session -d -s mfish
                mfish_ls $maildir_default | tmux send-keys -t mfish "less" Enter
                tmux attach -t mfish
            end
    end
end

# Prompt interactif
function mfish_prompt
    set -l maildir $argv[1]
    while true
        echo -n "mfish:$maildir> "
        read -l cmd args

        switch $cmd
            case fetch
                mfish_fetch $args
            case index
                mfish_index
            case ls
                mfish_ls $args
            case cd
                mfish_cd $args
            case show
                mfish_show $args
            case grep
                mfish_grep $args
            case rm
                mfish_rm $args
            case spam
                mfish_spam $args
            case cur
                mfish_cur $args
            case new
                mfish_new $args
            case help
                mfish_help
	    case quit
		mfish_quit
            case ''
                continue
            case \d+
                mfish_show $cmd
            case '*'
                echo "Unknown command: $cmd. Type 'help' for a list of commands."
        end
    end
end


# Commande fetch
function mfish_fetch
    set -l fetch_cmd (__mfish_get_profile_var MailFetchCommand)
    set -l fetch_sleep (__mfish_get_profile_var MailFetchSleep)

    set -q fetch_cmd; or set fetch_cmd "fdm -q"
    set -q fetch_sleep; or set fetch_sleep 30

    if contains -- "--daemon" $argv
        while true
	    echo "INFO: fetching new mails..."
            eval $fetch_cmd
	    echo "INFO: indexing new mails..."
            mfish_index
	    echo "INFO: Sleeping... $fetch_sleep seconds"
            sleep $fetch_sleep
        end
    else
	echo "INFO: fetching new mails..."
	eval $fetch_cmd
	echo "INFO: indexing new mails..."
        mfish_index
	echo "INFO: exiting"
    end
end

# Commande index
function mfish_index
    set -l index_cmd (__mfish_get_profile_var "IndexCommand")
    eval (or $index_cmd "mscan $maildir_default")
end

# Commande cd
function mfish_cd
    set -l target_dir (or $argv[1] $maildir_default)
    if test -d $target_dir
        set maildir $target_dir
    else
        echo "Error: Directory not found."
    end
end

# Commande ls
function mfish_ls
    set -l target_dir (or $argv[1] $maildir)
    #mlist $target_dir | msort -dr | head -25 | mthread | mseq -S | mscan
    mlist ~/mail/Reception | msort -dr | head -25 | mthread | mseq -S | mscan
end

# Commande show
function mfish_show
    set -l message_id (or $argv[1] "last")
    if test $message_id = "last"
        set message_id (mscan -last)
    end
    tmux split-window -h "mshow $maildir/$message_id"
end

# Commande grep (recherche dans les mails)
function mfish_grep
    mgrep $argv
end

# Commande rm (supprimer un mail)
function mfish_rm
    mrm $argv
end

# Commande spam (signaler un spam)
function mfish_spam
    mspam $argv
end

# Commande cur (changer vers le répertoire cur)
function mfish_cur
    set -l target_dir "$maildir/cur"
    if test -d $target_dir
        mfish_cd $target_dir
        mfish_ls
    else
        echo "Error: Directory 'cur' not found."
    end
end

# Commande new (changer vers le répertoire new)
function mfish_new
    set -l target_dir "$maildir/new"
    if test -d $target_dir
        mfish_cd $target_dir
        mfish_ls
    else
        echo "Error: Directory 'new' not found."
    end
end

# Commande quit (quitter la REPL)
function mfish_quit
    echo "Exiting mfish REPL. Goodbye!"
    exit
end


# Commande help
function mfish_help
    echo "Commands available in mfish:"
    echo "  fetch [--daemon]    Fetch mail"
    echo "  index               Index current maildir"
    echo "  ls [MAILDIR]        List messages in a maildir"
    echo "  cd [MAILDIR]        Change maildir"
    echo "  show [MESSAGE_ID]   Show a message"
    echo "  grep [PATTERN]      Search in maildir"
    echo "  rm [MESSAGE_ID]     Delete a message"
    echo "  spam [MESSAGE_ID]   Mark a message as spam"
    echo "  cur                  Switch to 'cur' directory"
    echo "  new                  Switch to 'new' directory"
    echo "  help                Show this help message"
end
