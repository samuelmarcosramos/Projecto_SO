#!/bin/bash

# Global Variables
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/ficheiros"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
LOG_FILE="$RECYCLE_BIN_DIR/log.txt"     
CONFIG_FILE="$RECYCLE_BIN_DIR/config"  

# Default configuration values
MAX_SIZE_MB=1024       # Tamanho máximo do recycle bin em MB
RETENTION_DAYS=30      # Dias de retenção antes da limpeza automática

# Color codes (precisamos definir para as cores funcionarem)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#################################################
# Function: log_message
# Description: Logs messages to log file
# Parameters: $1 - message to log
# Returns: None
#################################################
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE" #Dá append ao arquivo log.txt da data e hora do log e da mensagem
}


#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
    #Verify if the directory of the recycle_bin exists:
    if [ ! -d "$RECYCLE_BIN_DIR"]; then
        #Criar a estrutura de diretórios caso não exista e cria o diretório onde irão ser armazenados os ficheiros deletados:
        mkdir -p "$FILES_DIR"

        # Verifica se o arquivo metadata.db existe
        if [ ! -f "$METADATA_FILE" ]; then
            #Cria e inicializa o arquivo metadata.db
            echo "Recycle Bin Metadata" > "$METADATA_FILE"
            #Dá append do segunite texto ao arquivo metadata.db, de forma a mostrar a ordem da informação que vai aparecer em cada linha 
            echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
        fi
        
        # Cria arquivo de configuração com valores padrão
        echo "MAX_SIZE_MB=$MAX_SIZE_MB" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=$RETENTION_DAYS" >> "$CONFIG_FILE"

        # Cria e inicializa o arquivo de log apenas se ele não existir (Serve para manter um registo de todas as operações do sistema)
        if [ ! -f "$LOG_FILE" ]; then
            echo "# Recycle Bin Log File" > "$LOG_FILE" #Cria e inicializa o arquivo log.txt se n
            echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" #Dá append da data e hora que o log é feito
            echo "==========================================" >> "$LOG_FILE" #Dá append a esta linha que serve apenas de separação entre logs
        fi
        
        # Mensagem de sucesso (Informa o usuário e registra no log que a inicialização foi bem sucedida)
        echo -e "Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
        log_message "Recycle bin initialized"
    fi
    return 0  # Retorna sucesso
}

#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
local timestamp=$(date +%s)
local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -
n 1)
echo "${timestamp}_${random}"
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file(){
    # TODO: Implement this function
    local file_path="$1"
    # Validate input
    if [ -z "$file_path" ]; then
    echo -e "${RED}Error: No file specified${NC}"
    return 1
    fi
    # Check if file exists
    if [ ! -e "$file_path" ]; then
    echo -e "${RED}Error: File '$file_path' does not exist${NC}"
    return 1
    fi
    # Your code here
    # Hint: Get file metadata using stat command
    # Hint: Generate unique ID
    # Hint: Move file to FILES_DIR with unique ID
    # Hint: Add entry to metadata file
    echo "Delete function called with: $file_path"
    return 0
}

restore_file(){
    # TODO: Implement this function
    local file_id="$1"
    if [ -z "$file_id" ]; then
    echo -e "${RED}Error: No file ID specified${NC}"
    return 1
    fi
    # Your code here
    # Hint: Search metadata for matching ID
    # Hint: Get original path from metadata
    # Hint: Check if original path exists
    # Hint: Move file back and restore permissions
    # Hint: Remove entry from metadata

    return 0
}

#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
    # TODO: Implement this function
    echo "=== Recycle Bin Contents ==="
    # Your code here
    # Hint: Read metadata file and format output
    # Hint: Use printf for formatted table
    # Hint: Skip header line
}

#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # TODO: Implement this function
    # Your code here
    # Hint: Ask for confirmation
    # Hint: Delete all files in FILES_DIR
    # Hint: Reset metadata file

    return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    # TODO: Implement this function
    local pattern="$1"
    # Your code here
    # Hint: Use grep to search metadata
    return 0
}

#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help(){
    cat << EOF
Linux Recycle Bin - Usage Guide
SYNOPSIS:
    $0 [OPTION] [ARGUMENTS]
OPTIONS:
    delete <file>
    list
    restore <id>
    Move file/directory to recycle bin
    List all items in recycle bin
    Restore file by ID
    search <pattern>
    empty
    help
    Search for files by name
    Empty recycle bin permanently
    Display this help message
EXAMPLES:
    $0 delete myfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty
EOF
    return 0
}
    

#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
    # Initialize recycle bin
    initialize_recyclebin
    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            ;;
        list)
            list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
            empty_recyclebin
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}
