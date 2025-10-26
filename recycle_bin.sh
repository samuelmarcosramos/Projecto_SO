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
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
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
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
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

    # Hint: Get file metadata using stat command
    local filename=$(basename "$file_path") #filename fica com o valor do nome do arquivo
    local original_path=$(realpath "$file_path") #original_path fica com o valor do caminho absoluto do arquivo
    local deletion_date=$(date '+%Y-%m-%d %H:%M:%S')  #deletion_date fica com o valor da data e hora em que o arquivo foi eliminado
    local file_size=$(stat -c "%s" "$file_path" || echo "0") #file_size fica com o valor do tamanho do arquivo em bytes, caso stat falhe fica com o valor "0"
    local permissions=$(stat -c "%a" "$file_path" || echo "erro ao obter as permissões do arquivo")  #permissions  fica com o valor das permissões do arquivo, caso stat falhe fica com o valor "erro ao obter as permissões do arquivo"
    local owner=$(stat -c "%U:%G" "$file_path" || echo "user_name:group_name") #owner fica com o valor do user:group_name, caso stat falhe fica com o valor "user_name:group_name"
    
    # Determine file type
    local file_type="file"
    if [ -d "$file_path" ]; then
        file_type="directory"
        # For directories, get total size including contents
        file_size=$(du -sb "$file_path" | cut -f1 || echo "0") #du calcula o tamanho (mostra o tamanho total, ou seja se for uma pasta não mostra o tamanho de cada ficheiro em separado mas sim o tamanho total da pasta, isto graças a usar -sb (summarybytes)), cut extrai o número e a variável recebe o valor calculado por du e extraido por cut
    fi

    # Hint: Generate unique ID
    local unique_id=$(generate_unique_id) #chama a função para gerar um novo id único

    # Hint: Move file to FILES_DIR with unique ID
    if mv "$file_path" "$FILES_DIR/$unique_id";  then
    echo -e "${GREEN} Successfully moved to recycle bin: $filename${NC}"

    # Hint: Add entry to metadata file
    echo "$unique_id,$filename,$original_path,$deletion_date,$file_size,$file_type,$permissions,$owner" >> "$METADATA_FILE"
        
        # Log the operation
        log_message "Deleted: $filename (ID: $unique_id) from $original_path"
        
        echo -e "${BLUE}File ID: $unique_id${NC}"
        echo -e "${BLUE}Original location: $original_path${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to move '$filename' to recycle bin${NC}"
        log_message "Failed to delete: $filename from $original_path"
        return 1
    fi
    
    
    echo "Delete function called with: $file_path"
    return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file(){
    # TODO: Implement this function
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    # Hint: Search metadata for matching ID
    local entry=$(grep "^$file_id," "$METADATA_FILE") #procura a linha que começa com o file_id em METADATA_FILE
    if [ -z "$entry" ]; then #Verifica se foi encontrada alguma coisa ou se o tamanho da variável entry é 0
        echo -e "${RED}Error: File with ID '$file_id' not found in recycle bin${NC}"
        return 1
    fi

    #Hint: Get original path from metadata
    IFS=',' read -ra campos <<< "$entry"
    #Atribuição de variáveis
    local id="${campos[0]}"
    local original_name="${campos[1]}"
    local original_path="${campos[2]}"
    local deletion_date="${campos[3]}"
    local file_size="${campos[4]}"
    local file_type="${campos[5]}"
    local permissions="${campos[6]}"
    local owner="${campos[7]}"

    
    #Hint: Check if original path exists
    if [ ! -e "$FILES_DIR/$file_id" ]; then  # Verifica se o arquivo físico ainda existe no diretório files/ do recycle bin
        echo -e "${RED}Error: File '$original_name' not found in recycle bin files${NC}"
        return 1
    fi

    # Check if original directory exists, create if needed
    local parent_dir=$(dirname "$original_path") # Extrai o diretório pai do caminho original (remove o nome do arquivo)
    if [ ! -d "$parent_dir" ]; then  # Verifica se o diretório pai existe
        echo -e "${YELLOW}Original directory doesn't exist. Creating: $parent_dir${NC}"
        mkdir -p "$parent_dir" # Cria o diretório recursivamente (-p)
    fi

    # Check if file already exists at destination
    if [ -e "$original_path" ]; then # Verifica se já existe um arquivo no local de restauração
        echo -e "${YELLOW}File already exists at: $original_path${NC}"
        read -p "Overwrite? (y/n): " -n 1 -r # Pede confirmação (-n 1: lê apenas 1 char)
        echo # Quebra de linha após a resposta
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then # Verifica se a resposta NÃO foi Y ou y
            echo "Restore cancelled"
            return 1
        fi
    fi

    #Hint: Move file back and restore permissions
    if mv "$FILES_DIR/$file_id" "$original_path"; then # Move o arquivo do recycle bin de volta para o local original
        # Restore original permissions
        chmod "$permissions" "$original_path" # Restaura as permissões originais
        
        #Hint: Remove entry from metadata
        grep -v "^$file_id," "$METADATA_FILE" > "$METADATA_FILE.tmp" # grep -v: mostra tudo EXCETO as linhas que começam com file_id e redireciona para um arquivo temporário 
        mv "$METADATA_FILE.tmp" "$METADATA_FILE" # Substitui o arquivo original pelo temporário
        
        echo -e "${GREEN} Successfully restored: $original_name${NC}"
        echo -e "${BLUE}Restored to: $original_path${NC}"
        log_message "Restored: $original_name to $original_path" # Registra no log
        return 0
    else
        echo -e "${RED}Error: Failed to restore '$original_name'${NC}"
        log_message "Failed to restore: $original_name to $original_path"
        return 1
    fi

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
