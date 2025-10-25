#!/bin/bash

# Global Variables
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
$FILES_DIR="$RECYCLE_BIN_DIR/ficheiros"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"

# Default configuration values
MAX_SIZE_MB=1024       # Tamanho máximo da lixeira em MB
RETENTION_DAYS=30      # Dias de retenção antes da limpeza automática

# Function declarations
initialize_recyclebin() {
    #Verify if the directory of the recycle_bin exists:
    if [ ! -d "$RECYCLE_BIN_DIR"]; then
        #Criar a estrutura de diretórios caso não exista e cria o diretório onde irão ser armazenados os ficheiros deletados:
        mkdir -p "$FILES_DIR"

        # Cria e inicializa o arquivo de metadados
        if [ ! -f "$METADATA_FILE" ]; then
            echo "# Recycle Bin Metadata" > "$METADATA_FILE"
            echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
        fi
        
        # Cria arquivo de configuração com valores padrão
        echo "MAX_SIZE_MB=$MAX_SIZE_MB" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=$RETENTION_DAYS" >> "$CONFIG_FILE"

        # Create log file only if it doesn't exist
        if [ ! -f "$LOG_FILE" ]; then
            touch "$LOG_FILE"
            echo "# Recycle Bin Log File" > "$LOG_FILE"
            echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
            echo "==========================================" >> "$LOG_FILE"
        fi
        
        # Mensagem de sucesso
        echo -e "${GREEN}Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
        log_message "Recycle bin initialized"
    fi
    return 0  # Retorna sucesso
}

delete_file()

restore_file()

list_recycled()

empty_recyclebin()

search_recycled()

display_help()

# Main program logic
main()