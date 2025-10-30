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
    #Confirmação se o diretório RECYCLE_BIN_DIR ($HOME/.recycle_bin) existe
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then #Caso não exista:

        #Criação do diretório FILES_DIR ($RECYCLE_BIN_DIR/ficheiros) e dos seus parentes ($HOME/.recycle_bin):
        mkdir -p "$FILES_DIR"

        #Criação do ficheiro metadata.db
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        
        #Criação do ficheiro log.txt
        touch "$LOG_FILE"

        #Criação do ficheiro config
        echo "MAX_SIZE_MB=$MAX_SIZE_MB" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=$RETENTION_DAYS" >> "$CONFIG_FILE"

        #Mensagem adicionada ao log.txt
        log_message "Recycle bin initialized"

        #Saída a confirmar o sucesso da ação
        echo -e "${GREEN} Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
        return 0
    fi
    return 0
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
# Parameters: $1 - path to file/directory (supports multiple files)
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
    local success_count=0
    local fail_count=0

    # Verifica se não existem argumentos
    if [ $# -eq 0 ]; then #Caso não existam (nº de argumentos = 0)

        #Mensagem de erro 
        echo -e "${RED}Error: No files specified${NC}"

        return 1
    fi

    # Process each file/directory
    for file_path in "$@"; do
        if delete_single_file "$file_path"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # Feedback ao user do sucesso ou falha ao eliminar ficheiros
    if [ $# -gt 1 ]; then #Caso exista argumentos
        
        #Verifica se o counter de operações bem sucedidas é maior que 0
        if [ "$success_count" -gt 0 ]; then 

            #Mensagem a dizer ao user quantos ficheiros foram eliminados com sucesso
            echo -e "${GREEN} $success_count item(s) of $# moved to recycle bin${NC}"

        fi
        
        #Verifica se o counter de operações falhadas é maior que 0
        if [ "$fail_count" -gt 0 ]; then

            #Mensagem a dizer ao user quantos ficheiros falharam em ser eliminados
            echo -e "${RED} $fail_count item(s) of $# failed to delete${NC}"

        fi
    fi

    #Verifica se a ação foi bem sucedida ou se existiu alguma falha
    if [ "$fail_count" -gt 0 ]; then

        return 1
    else
        return 0
    fi
}


#################################################
# Function: delete_single_file
# Description: Moves a single file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_single_file() {
    local file_path="$1"

    # Verifica se existem argumentos
    if [ -z "$file_path" ]; then #Caso o tamanho de file_path = 0:

        #Mensagem de erro
        echo -e "${RED}Error: No file specified${NC}"

        return 1
    fi

    # Verifica se o ficheiro existe
    if [ ! -e "$file_path" ]; then #Caso não exista:

        #Mensagem de erro a dizer que o ficheiro que o user está a tentar eliminar não existe
        echo -e "${RED}Error: File '$file_path' does not exist${NC}"

        return 1
    fi

    # Obtém os caminhos absolutos do ficheiro que o user está a tentar eliminar e do recycle bin, para realizar verificações
    local original_path=$(realpath "$file_path" || echo "$file_path")
    local recycle_bin_path=$(realpath "$RECYCLE_BIN_DIR")
    
    # Verifica se o utilizador está a tentar eliminar o recycle bin ou algum subdiretório
    if [ "$original_path" = "$recycle_bin_path" ] || [[ "$original_path" == "$recycle_bin_path"/* ]]; then #Caso esteja:

        #Mensagem de erro a proibir de eliminar o recyclebin ou o que ele contém
        echo -e "${RED}Error: Cannot delete the recycle bin itself or its contents${NC}"

        return 1
    fi

    # Verifica se o user tem permissão de leitura do ficheiro/diretório (Só é possivel mover (mv) um ficheiro/diretório se o user tiver permissão de leitura sobre este)
    if [ ! -r "$file_path" ]; then #Caso não tenha permissão:

        #Mensagem de erro a informar que a açao não pode ser concluida devido a não ter permissão de leitura
        echo -e "${RED}Error: No read permission for '$file_path'${NC}"

        return 1
    fi

    #Verificação permissões:

    # Verifica se o user tem permissão de escrita no diretório pai (Só é possivel mover (mv) um ficheiro/diretório de um diretório se o user tiver permissão de escrita no diretório pai)
    if [ ! -w "$(dirname "$file_path")" ]; then #Caso não tenha permissão:

        #Mensagem de erro a informar que a açao não pode ser concluida devido a não ter permissão de escrita no diretório pai
        echo -e "${RED}Error: No write permission for directory of '$file_path'${NC}"

        return 1
    fi

    # Verificação se o user tem permissão de escrita no diretório (Só é possivel mover (mv) um diretório se o user tiver permissão de escrita nesse diretório)
    if [ -d "$original_path" ] && [ ! -w "$original_path" ]; then

        #Mensagem de erro a informar que a açao não pode ser concluida devido a não ter permissão de escrita no diretório
        echo -e "${RED}Error: No write permission for directory '$original_path'${NC}"

        return 1
    fi

    # Verificação se existe espaço suficiente no recycle bin
    
    local file_size=$(du -sb "$file_path" | awk '{print $1}') #Tamanho do ficheiro ou diretório em bytes

    local max_size_bytes=$((MAX_SIZE_MB * 1024 * 1024)) #Tamanho máximo do recycle bin convertido para bytes

    local current_usage=$(du -sb "$FILES_DIR" | awk '{print $1}') #Tamanho atual que os ficheiros ocupam atualmente

    local available_space=$((max_size_bytes-current_usage)) #Obtém o o espaço disponível (primeira linha)

    #Verifica se o tamanho do ficheiro é maior do que o espaço disponivel
    if [ "$file_size" -gt "$available_space" ]; then #Caso seja:

        #Mensagem de erro a dizer que é impossível mover o ficheiro pra o recycle bin, devido à falta de espaço
        echo -e "${RED}Error: Insufficient disk space to move '$file_path' to recycle bin${NC}"

        return 1
    fi

    # Obtém os metadata
    local filename=$(basename "$file_path")
    local abs_path=$(realpath "$file_path")
    local permissions=$(stat -c %a "$file_path")
    local owner=$(stat -c %U:%G "$file_path")
    local deletion_date=$(date "+%Y-%m-%d %H:%M:%S")

    
    # Determina o tipo de ficheiro por defeito:
    local file_type="file"

    #Verifica se o ficheiro é um diretório
    if [ -d "$file_path" ]; then #Caso seja:

        file_type="directory" #Muda o valor da variável para "directory"

    fi

    # Gera um ID único para cada item eliminado
    local unique_id=$(generate_unique_id)

    # Mensagem a confirmar que os ficheiros irão ser movidos para o $FILES_DIR com um ID único
    echo -e "${YELLOW}Moving '$filename' to recycle bin...${NC}"
    

    if mv "$file_path" "$FILES_DIR/$unique_id"; then #Caso a ação seja realizada:
        
        # Append metadata ao metadata.db
        echo "$unique_id,$filename,$abs_path,$deletion_date,$file_size,$file_type,$permissions,$owner" >> "$METADATA_FILE"
        
        # Log todas as operaçoes para o recyclebin.log
        log_message "Deleted: $filename (ID: $unique_id) from $original_path - Size: $file_size bytes"
        
        # Dar feedback ao user
        echo -e "${GREEN} Successfully moved to recycle bin: $filename${NC}"
        echo -e "${BLUE}  File ID: $unique_id${NC}"
        echo -e "${BLUE}  Original location: $original_path${NC}"
        echo -e "${BLUE}  Size: $file_size bytes${NC}"
        echo -e "${BLUE}  Type: $file_type${NC}"
        
        return 0
    else

        #Mensagem de erro, a dar a conhecer ao user que a ação falhou
        echo -e "${RED}Error: Failed to move '$filename' to recycle bin${NC}"

        # Log do erro ao realizar a ação para o recyclebin.log
        log_message "Failed to delete: $filename from $original_path"

        return 1
    fi
}


#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID or filename of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    local search_term="$1" # Aceita filename ou ID para restaurar
    
    # Verifica se existe algum argumento
    if [ -z "$search_term" ]; then #Caso não exista:

        #Mensagem de erro a identificar o erro
        echo -e "${RED}Error: No file ID or filename specified${NC}"
    
        return 1
    fi

    # Procura na metadata uma entrada que coincida com o argumento
    local entry #variável de entrada

    #Verifica se o argumento é um ID utilizando regex "[[]]"
    if [[ "$search_term" =~ ^[0-9]+_[a-z0-9]+$ ]]; then #Caso seja:

        # Procura por ID
        entry=$(grep "^$search_term," "$METADATA_FILE")

    else #Caso contrário

        # Procura por filename (case-insensitive)
        entry=$(grep -i ",$search_term," "$METADATA_FILE")
        
    fi

    # Verifica se o ID ou o filename não foi encontrado
    if [ -z "$entry" ]; then #Caso não tenha sido encontrado:

        #Mensagem de erro a explicar o erro
        echo -e "${RED}Error: File '$search_term' not found in recycle bin${NC}"

        return 1
    fi

    # Divide pelos campos de metadata a entry
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$entry" #Entry é passado como input ao comando read que divide cada campo por virgulas

    # Verifica, caso o user tentar o restauro através do filename, se existe mais do que um ficheiro com o mesmo nome
    if [[ ! "$search_term" =~ ^[0-9]+_[a-z0-9]+$ ]]; then #Caso o user tente o restauro do ficheiro por filename:

        #Conta o número de linhas (ficheiros com o mesmo nome (case insensitive))
        local match_count=$(grep -i ",$original_name," "$METADATA_FILE" | wc -l)

        #Verifica se existe mais do que um ficheiro com o mesmo nome
        if [ "$match_count" -gt 1 ]; then #Caso exista:
        
            #Mensagem de erro a informar que existe mais de um ficheiro com esse nome
            echo -e "${YELLOW}Warning: Multiple files named '$original_name' found in recycle bin${NC}"
            
            #Pede ao utilizador para tentar restaurar usando ID    
            echo -e "${YELLOW}Using the most recently deleted one. Use specific ID for exact match.${NC}"
        
        fi

    fi

    # Verifica se o ficheiro existe no recycle bin
    if [ ! -e "$FILES_DIR/$id" ]; then #Caso não exista:

        #Mensagem de erro a infromar que o ficehiro não se encontra no recycle bin
        echo -e "${RED}Error: File '$original_name' not found in recycle bin storage${NC}"
    
        return 1
    fi

    # Conflitos ao restaurar:
    
    # 1 - Se o path orginal já não existir, criar diretório 
    # Obter o diretório pai do ficheiro/diretório
    local parent_dir=$(dirname "$original_path")

    #Verifica se o diretório existe
    if [ ! -d "$parent_dir" ]; then #Caso não exista.

        # Mensagem a informar que o diretório vai ser criado
        echo -e "${YELLOW}Original directory doesn't exist. Creating: $parent_dir${NC}"

        #Tenta criar o diretório e verifica se o comando foi bem sucedido
        if ! mkdir -p "$parent_dir"; then #Caso tenha falhado:

            #Mensagem de erro a informar que não foi possível criar o diretório
            echo -e "${RED}Error: Failed to create directory '$parent_dir'${NC}"

            return 1
        fi
    fi

    # 2 - Verifica se o user tem autorização de escrita no diretório pai
    if [ ! -w "$parent_dir" ]; then #Caso não tenha:

        #Mensagem de erro a infromar a impossíbilidade de realizar esta operção devido à falta de permissão de escrita no diretório pai
        echo -e "${RED}Error: Permission denied. Cannot write to '$parent_dir'${NC}"
        
        return 1
    fi

    # 3 - Verifica problemas com o espaço
    local available_space=$(df "$parent_dir" | awk 'NR==2 {print $4}') #Obtém o espaço disponível no diretório pai

    #Verifica se o tamanho do ficheiro é superior ao espaço disponível
    if [ "$file_size" -gt "$available_space" ]; then #Caso seja:

        #Mensagem de erro a informar da falha da operação devido à falta de espaço disponível
        echo -e "${RED}Error: Insufficient disk space to restore '$original_name'${NC}"

        #Mensagem a mostrar ao user o tamanho do ficheiro e o espaço disponível
        echo -e "${RED}Required: $file_size bytes, Available: $available_space bytes${NC}"

        return 1
    fi

    # 4 - Se o ficheiro já existir no original path, perguntar ao user o que fazer
    #Variável que irá ter o novo caminho
    local restore_path

    #Variável que permite confirmar quando o problema é resolvido
    local conflict_resolved=false
    
    #Verifica se o original path já existe
    if [ -e "$original_path" ]; then #Caso exista:

        #Mensagem a informar que o ficheiro já existe no original path
        echo -e "${YELLOW}File already exists at: $original_path${NC}"

        #Mensagem a pedir ao user para escolher uma opção do que fazer
        echo "Choose an option:"
        echo "1) Overwrite existing file"
        echo "2) Restore with modified name"
        echo "3) Cancel operation"
        
        #Ciclo que enquanto o problema não for resolvido pede ao user o que fazer (dentro das opções disponíveis)
        while [ "$conflict_resolved" = false ]; do

            #Lê o input do user e armazena-o em choice
            read -p "Enter your choice (1-3): " choice
            
            case $choice in
                #Caso choice = 1
                1) 
                    #Overwrite existing file
                    
                    #Tenta remover permanentemente o ficheiro que se quer substituir e verifica se o comando foi bem sucedido
                    if rm -rf "$original_path" ; then #Caso seja:

                        #A variável restore_path fica com o valor do original_path
                        restore_path="$original_path"

                        #conflict_resolved passa a true e encerra o ciclo
                        conflict_resolved=true

                    else #Caso o comando não seja bem sucedido:

                        #Mensagem de erro
                        echo -e "${RED}Error: Cannot overwrite file. Permission denied.${NC}"

                        return 1
                    fi
                    ;;

                #Caso choice = 2    
                2)
                    # Restore with modified name

                    #Variável com o original_name
                    local basename="${original_name%.*}"

                    #Variável com 
                    local extension="${original_name##*.}"


                    local timestamp=$(date +%Y%m%d_%H%M%S)
                    
                    if [ "$extension" = "$original_name" ]; then
                        # No extension
                        restore_path="$parent_dir/${basename}_${timestamp}"
                    else
                        restore_path="$parent_dir/${basename}_${timestamp}.${extension}"
                    fi
                    
                    echo -e "${YELLOW}Restoring as: $(basename "$restore_path")${NC}"

                    #conflict_resolved passa a true e encerra o ciclo
                    conflict_resolved=true
                    ;;

                #Caso choice = 3    
                3)
                    # Cancel operation

                    #Mensagem a informar do cancelamento da operção
                    echo -e "${YELLOW}Restore cancelled${NC}"

                    return 1
                    ;;

                #Caso choice for inválida (diferente de 1,2 ou 3)   
                *)
                    #Mensagem a informar que o input é inválido
                    echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                    ;;
            esac
        done
    fi

    # Restaura o ficheiro com o caminho absoluto original
    echo -e "${YELLOW}Restoring: $original_name${NC}"
    echo -e "${BLUE}From: $FILES_DIR/$id${NC}"
    echo -e "${BLUE}To: $restore_path${NC}"

    #Verifica se o comando foi bem sucedido
    if mv "$FILES_DIR/$id" "$restore_path"; then #Caso seja:

        # Restaura as permissões originais usando chmod
        #Verifica se o comando é bem sucedido
        if ! chmod "$permissions" "$restore_path"; then #Caso não seja:

            #Mensagem de erro a informar da falha da operação
            echo -e "${YELLOW}Warning: Could not restore original permissions${NC}"
        fi

        # Remover entry de metadata.db depois da restauração ter sido bem sucedida
        #A linha do METADATA_FILE que contém a informação do id do ficheiro que vai ser restaurado é eliminada e as restantes linhas são guardadas num ficheiro temporário, depois caso este primeiro comando seja bem sucedido, o metadata.db é atualizado, para além disso verifica se os comandos foram bem sucedidos
        if grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"; then #Caso sejam bem sucedidos:
            
            # É dado feedback ao user sobre a restauração incluindo o path para onde foi o ficheiro
            echo -e "${GREEN} Successfully restored: $original_name${NC}"
            echo -e "${BLUE}Location: $restore_path${NC}"
            
            # Log as operações de restauração   
            log_message "Restored: $original_name to $restore_path (ID: $id)"

            return 0
    else #Caso o comando de restauração falhe:

        #Mensagem de erro a informar da falha da operação
        echo -e "${RED}Error: Failed to restore '$original_name'${NC}"

        #Log da falha da operação em log.txt
        log_message "Failed to restore: $original_name to $restore_path"

        return 1
    fi
}


#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {

    #Variável que permite saber se o user quer ver a lista com detalhe 
    local detailed_mode=0
    
    #Verifica se foi passado o argumento --detailed
    if [ "$1" = "--detailed" ]; then #Caso tenha sido:
        
        #Altera para o modo (datailed_mode = 1)
        detailed_mode=1

    fi

    #Verifica se o recycle bin não existe ou se está vazio
    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then #Caso o ficheiro de metadata não exista ou esteja vazio:

        #Mensagem a dizer que o recycle bin está vazio
        echo "Recycle bin is empty"

        return 0
    fi

    #Conta o número de linhas em metadata
    local line_count=$(wc -l < "$METADATA_FILE")
    
    #Calcula o número de itens (subtrai a linha do cabeçalho)
    local item_count=$((line_count - 1))
    
    #Verifica não existem itens
    if [ "$item_count" -eq 0 ]; then #Caso não existam:

        #Mensagem a dizer que o recycle bin está vazio
        echo "Recycle bin is empty"
        
        return 0
    fi

    #Mostra todos os itens atualmente no recycle bin, confirmando primeiro se deve mostrar a informação em detalhe ou de forma normal
    if [ "$detailed_mode" -eq 1 ]; then #Caso esteja no modo detalhado:
        
        #Chama a função e mostra vista detalhada
        list_detailed_view
    else #Caso contrário:
    
        #Chama a função e mostra vista normal
        list_normal_view
    fi

    return 0
}


#################################################
# Function: list_normal_view
# Description: Shows compact table view
# Parameters: None
# Returns: 0 on success
#################################################
list_normal_view() {
    #Variável tamanho total
    local total_size=0

    #Contagem do nº de items
    local item_count=0
    
    #Título
    echo " Recycle Bin Items"
    
    #Cabeçalho da tabela com colunas formatadas
    printf "%-18s %-25s %-20s %-12s\n" "ID" "FILENAME" "DELETION_DATE" "SIZE"
    
    #Linha a separar
    echo "----------------------------------------------------------------"
    
    #Lê o ficheiro de metadata linha a linha e separa os campos por vírgulas
    while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        
        #Verifica se não é a linha do cabeçalho
        if [ "$id" != "ID" ]; then #Caso não seja:

            #Formata o ID para display (primeiros 12 caracteres + "...")
            display_id="${id:0:12}..."
            
            #Nome original do ficheiro (cortado se for muito longo)
            local display_name="$original_name"
            
            #Verifica se o nome do ficheiro é maior que 23 caracteres
            if [ ${#display_name} -gt 23 ]; then #Caso seja:

                #Mostra apenas 20 caracteres e adiciona "..."
                display_name="${display_name:0:20}..."
            fi
            
            #Formata a data para display (primeiros 16 caracteres)
            display_date="${deletion_date:0:16}"
            
            #Formato simples do tamanho
            if [ "$file_size" -lt 1024 ]; then #Caso o tamanho seja menor que 1KB:
            
                #Mostra o tamanho em bytes
                display_size="${file_size}B"
                
            elif [ "$file_size" -lt 1024 * 1024 ]; then #Caso o tamanho seja menor que 1MB:
            
                #Converte para KB e mostra
                display_size="$((file_size / 1024))KB"
                
            elif [ "$file_size" -lt 1024 * 1024 * 1024 ]; then #Caso o tamanho seja menor que 1GB:
            
                #Converte para MB e mostra
                display_size="$((file_size / 1024 / 1024))MB"
                
            else #Caso o tamanho seja maior ou igual a 1GB:
            
                #Converte para GB e mostra
                display_size="$((file_size / 1024 / 1024 / 1024))GB"
            fi
            
            #Mostra a linha formatada da tabela
            printf "%-18s %-25s %-20s %-12s\n" "$display_id" "$display_name" "$display_date" "$display_size"
            
            #Adiciona o tamanho do ficheiro ao tamanho total
            total_size=$((total_size + file_size))

            #Adiciona 1 item à contagem
            item_count=$((item_count + 1))
        fi
        
    done < "$METADATA_FILE" #O ficheiro de metadata é usado como entrada para o loop while
    
    #Linha a separar o final
    echo "----------------------------------------------------------------"
    
    #Formata o tamanho total para display
    local display_total_size
    
    #Verifica o tamanho total e formata
    if [ "$total_size" -lt 1024 ]; then #Caso seja menor que 1KB:
    
        display_total_size="${total_size}B"
        
    elif [ "$total_size" -lt 1024 * 1024 ]; then #Caso seja menor que 1MB:
    
        display_total_size="$((total_size / 1024))KB"
        
    elif [ "$total_size" -lt 1024 * 1024 * 1024 ]; then #Caso seja menor que 1GB:
    
        display_total_size="$((total_size / 1024 / 1024))MB"
        
    else #Caso seja maior ou igual a 1GB:
    
        display_total_size="$((total_size / 1024 / 1024 / 1024))GB"
    fi
    
    #Mostra totais finais
    echo "Total items: $item_count"
    echo "Total size: $display_total_size"
}


#################################################
# Function: list_detailed_view
# Description: Shows full information per item
# Parameters: None
# Returns: 0 on success
#################################################
list_detailed_view() {
    #Variável tamanho total
    local total_size=0

    #Contagem do nº de items
    local item_count=0
    
    #Contagem de ficheiros
    local file_count=0
    
    #Contagem de diretórios
    local dir_count=0
    
    #Título
    echo " Recycle Bin Items (Detailed View)"
    
    #Lê o ficheiro de metadata linha a linha e separa os campos por vírgulas
    while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        
        #Verifica se não é a linha do cabeçalho
        if [ "$id" != "ID" ]; then #Caso não seja:

            #Conta os tipos de ficheiro
            if [ "$file_type" = "file" ]; then #Caso seja um ficheiro:

                #Adiciona 1 ao contador de ficheiros
                ((file_count++))
            else #Caso seja um diretório:

                #Adiciona 1 ao contador de diretórios
                ((dir_count++))
            fi
            
            #Mostra informação completa por item
            echo "============================================================"
            echo " Item: $((item_count + 1))"
            echo "------------------------------------------------------------"
            
            #Mostra cada campo do metadata
            printf "%-15s: %s\n" "ID" "$id"
            printf "%-15s: %s\n" "Filename" "$original_name"
            printf "%-15s: %s\n" "Original Path" "$original_path"
            printf "%-15s: %s\n" "Deleted" "$deletion_date"
            
            #Tamanho do ficheiro
            local display_size
            
            #Verifica o tamanho do ficheiro e formata apropriadamente
            if [ "$file_size" -lt 1024 ]; then #Caso seja menor que 1KB:
            
                display_size="${file_size} bytes"
                
            elif [ "$file_size" -lt 1024 * 1024 ]; then #Caso seja menor que 1MB:
            
                display_size="$((file_size / 1024)) KB"
                
            elif [ "$file_size" -lt 1024 * 1024 * 1024 ]; then #Caso seja menor que 1GB:
            
                display_size="$((file_size / 1024 / 1024)) MB"
                
            else #Caso seja maior ou igual a 1GB:
            
                display_size="$((file_size / 1024 / 1024 / 1024)) GB"
            fi
            
            printf "%-15s: %s\n" "Size" "$display_size"
            printf "%-15s: %s\n" "Type" "$file_type"
            printf "%-15s: %s\n" "Permissions" "$permissions"
            printf "%-15s: %s\n" "Owner" "$owner"
            echo "============================================================"
            echo
            
            #Adiciona o tamanho  do ficheiro ao tamanho total
            total_size=$((total_size + file_size))

            #Adiciona 1 item à contagem
            item_count=$((item_count + 1))
        fi
        
    done < "$METADATA_FILE" #O ficheiro de metadata é usado como entrada para o loop while
    
    #Mostra o resumo
    echo "=== Summary ==="
    
    #Mostra contagens totais
    echo "Total items: $item_count"
    echo "Files: $file_count"
    echo "Directories: $dir_count"
    
    #Formata o armazenamento total usado
    local display_total_size
    
    # Verifica o tamanho total e formata apropriadamente
    if [ "$total_size" -lt 1024 ]; then #Caso seja menor que 1KB:
    
        display_total_size="${total_size} bytes"
        
    elif [ "$total_size" -lt 1024 * 1024 ]; then #Caso seja menor que 1MB:
    
        display_total_size="$((total_size / 1024)) KB"
        
    elif [ "$total_size" -lt 1024 * 1024 * 1024 ]; then #Caso seja menor que 1GB:
    
        display_total_size="$((total_size / 1024 / 1024)) MB"
        
    else #Caso seja maior ou igual a 1GB:
    
        display_total_size="$((total_size / 1024 / 1024 / 1024)) GB"
    fi
    
    #Mostra o armazenamento total usado
    echo "Total storage used: $display_total_size"
    
    #Verifica se existem items
    if [ "$item_count" -gt 0 ]; then #Caso existam:

        #Calcula o tamanho médio
        local avg_size=$((total_size / item_count))
        local display_avg_size
        
        #Formata o tamanho médio para display
        if [ "$avg_size" -lt 1024 ]; then #Caso seja menor que 1KB:
        
            display_avg_size="${avg_size} bytes"
            
        elif [ "$avg_size" -lt 1024 * 1024 ]; then #Caso seja menor que 1MB:
        
            display_avg_size="$((avg_size / 1024)) KB"
            
        else #Caso seja maior ou igual a 1MB:
        
            display_avg_size="$((avg_size / 1024 / 1024)) MB"
        fi
        
        #Mostra o tamanho médio de um item
        echo "Average item size: $display_avg_size"

    fi
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items or specific item by ID
# Parameters: 
#   $1 - "--force" to skip confirmation
# Returns: 0 on success, 1 on failure
#################################################
empty_recyclebin() {

    #Argumento passado pelo user que permite identificar se está ou não em force_mode
    local target="$1"
    local force_mode=0
    
    #Verificar se o user utilizou a --force flag
    if [ "$target" = "--force" ]; then #Caso tenha utilizado:

        #Ativa o force mode (force_mode=1)
        force_mode=1

    fi

    #Verifica se o recycle bin está vazio 
    local line_count=$(wc -l < "$METADATA_FILE" || echo 0) #Conta o nº de linhas de METADATA_FILE

    if [ ! -f "$METADATA_FILE" ] || [ "$line_count" -le 1 ]; then #Caso o ficheiro de metadata não exista ou tenha 1 ou menos linhas:

        #Mensagem a informar que o recycle bin já está vazio
        echo "Recycle bin is already empty"

        return 0
    fi

    #Conta o nºde linhas a  apagar 
    local item_count=$((line_count - 1))
    
    #Pede a confirmação do user antes da eliminação permanente (a menos que esteja em --force)
    if [ "$force_mode" -eq 0 ]; then #Caso não esteja em force mode:

        #Mensagem de aviso sobre a eliminação permanente
        echo "**WARNING:** This will permanently delete all $item_count items"
        echo "This action cannot be undone!"
        
        #Pede confirmação ao user
        read -p "Are you sure? (y/n): " -n 1 -r
        echo

        #Verifica se o user deu autorização para proseguir com a ação
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then #Caso o user não dê autorização:

            #Mensagem a informar que a operação foi cancelada
            echo "Operation cancelled"

            return 1
        fi

    else #Caso esteja em force mode:

        #Mensagem a informar que está em modo force
        echo "Force mode: Emptying recycle bin without confirmation"

    fi

    #Elimina permanentemente os ficheiros usando rm -rf
    echo "Deleting files from recycle bin..."
    if [ -d "$FILES_DIR" ] && [ "$(ls -A "$FILES_DIR")" ]; then #Caso o diretório de ficheiros exista e não esteja vazio:

        #Tenta eliminar todos os ficheiros do diretório
        if rm -rf "$FILES_DIR"/*; then #Caso o comando seja bem sucedido:

            #Mensagem a confirmar que todos os ficheiros foram eliminados
            echo "All files deleted from recycle bin"

        else #Caso o comando falhe:

            #Mensagem de erro a informar que alguns ficheiros não foram eliminados
            echo "Error: Failed to delete some files"

        fi

    else #Caso o diretório não exista ou esteja vazio:

        #Mensagem a informar que não foram encontrados ficheiros
        echo "No files found in recycle bin directory"

    fi

    #Atualiza o ficheiro de metadata
    echo "Clearing metadata..."

    #Inicializa o file METADATA_FILE, apenas com a linha de cabaçalho
    if echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"; then #Caso o comando seja bem sucedido:

        #Mensagem a confirmar que o metadata foi limpo
        echo "Metadata cleared"

    else #Caso o comando falhe:

        #Mensagem de erro a informar que não foi possível limpar o ficheiro de metadata
        echo "Error: Failed to clear metadata file"

        return 1
    fi

    # Mostra sumário dos itens eliminados
    echo "Recycle bin emptied successfully"
    echo "$item_count items permanently deleted"
    
    #Regista a operação no log
    log_message "Recycle bin emptied - $item_count items permanently deleted"
    
    return 0
}


#################################################
# Function: empty_specific_file
# Description: Permanently deletes a specific file by ID
# Parameters: 
#   $1 - file ID to delete
#   $2 - force mode (0=ask confirmation, 1=skip confirmation)
# Returns: 0 on success, 1 on failure
#################################################
empty_specific_file() {

    #ID do file a eliminar
    local file_id="$1"
    #egundo argumento, com valor padrão 0
    local force_mode="${2:-0}"

    #Verifica se o user meteu file_id
    if [ -z "$file_id" ]; then #Caso o file_id esteja vazio:

        #Mensagem de erro a identificar a falta de file_id
        echo "Error: No file ID specified"

        return 1
    fi

    #Procura o ficheiro no metadata por id
    local entry=$(grep "^$file_id," "$METADATA_FILE")

    if [ -z "$entry" ]; then #Caso a entrada não seja encontrada:

        #Mensagem de erro a informar que o ficheiro não foi encontrado
        echo "Error: File with ID '$file_id' not found in recycle bin"

        return 1
    fi

    #Divide a entrada do metadata nos seus campos
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$entry"
    
    #Pede a confirmação do user antes da eliminação permanente (a menos que esteja em --force)
    if [ "$force_mode" -eq 0 ]; then #Caso não esteja em force mode:

        #Mostra informação sobre o ficheiro a ser eliminado
        echo "About to permanently delete:"
        echo "  Name: $original_name"
        echo "  Original path: $original_path"
        echo "  Deleted: $deletion_date"
        echo "  Size: $file_size bytes"
        echo "This action cannot be undone!"
        
        #Pede confirmação ao user
        read -p "Are you sure? (y/n): " -n 1 -r
        echo

        #Verifica se o user deu autorização para proseguir com a ação
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then #Caso o user não deia autorização:

            #Mensagem a informar que a operação foi cancelada
            echo "Operation cancelled"

            return 1
        fi

    fi

    # Elimina permanentemente o ficheiro específico usando rm -rf
    if [ -e "$FILES_DIR/$file_id" ]; then #Caso o ficheiro exista no diretório de ficheiros:

        #Tenta eliminar o ficheiro
        if rm -rf "$FILES_DIR/$file_id"; then #Caso o comando seja bem sucedido:

            #Mensagem a confirmar que o ficheiro foi eliminado permanentemente
            echo "File '$original_name' permanently deleted"

        else #Caso o comando falhe:

            #Mensagem de erro a informar que não foi possível eliminar o ficheiro
            echo "Error: Failed to delete file '$original_name'"

            return 1
        fi

    else #Caso o ficheiro não exista no armazenamento:

        #Mensagem de aviso a informar que o ficheiro não foi encontrado
        echo "Warning: File not found in storage, but removing from metadata"

    fi

    # Atualiza o ficheiro de metadata (Adiciona tudo o que não corresponde aos padrões da pesquisa a um ficheiro temporário e depois substitui o ficheiro metadata file pelo temporário, já sem a linha do ficheiro eliminado)
    if grep -v "^$file_id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"; then #Caso os comandos sejam bem sucedidos:

        #Mensagem a confirmar que foi removido da base de dados de metadata
        echo "Removed from metadata database"
        
        # Mostra sumário do item eliminado
        echo "File '$original_name' permanently deleted"
        
        #Regista a operação no log
        log_message "Permanently deleted: $original_name (ID: $file_id)"

        return 0

    else #Caso os comandos falhem:

        #Mensagem de erro a informar que não foi possível atualizar a base de dados de metadata
        echo "Error: Failed to update metadata database"
        
        return 1
    fi
}


#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    local pattern="$1"

    #Verifica se foi especificado um padrão de pesquisa
    if [ -z "$pattern" ]; then #Caso o pattern esteja vazio:

        #Mensagem de erro a informar a falta de padrão de pesquisa
        echo "Error: No search pattern specified"
        echo "Usage: search <filename|ID|path|wildcard>"

        return 1
    fi

    #Verifica se o recycle bin está vazio
    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then #Caso o ficheiro de metadata não exista ou esteja vazio:

        #Mensagem a informar que o recycle bin está vazio
        echo "Recycle bin is empty"

        return 0
    fi

    local search_by=""

    #Determina o tipo de pesquisa com base no padrão
    if [[ "$pattern" =~ ^[0-9]+_[a-z0-9]+$ ]]; then #Caso o pattern seja um ID:

        #Define o tipo de pesquisa como ID
        search_by="id"
        echo "Searching by ID: $pattern"

    elif [[ "$pattern" == *[\*\?]* ]]; then #Caso o pattern contenha wildcards:

        #Define o tipo de pesquisa como wildcard
        search_by="wildcard"
        echo "Searching with wildcards: $pattern"

    elif [[ "$pattern" == */* ]]; then #Caso o pattern seja um caminho:

        #Define o tipo de pesquisa como path
        search_by="path"
        echo "Searching by path: $pattern"

    else #Caso não seja nenhum dos tipos anteriores:

        #Define o tipo de pesquisa como filename
        search_by="filename"
        echo "Searching by filename: $pattern"
    fi

    #Mostra cabeçalho da pesquisa
    echo "=== Search Results ==="
    
    #Mostra cabeçalho da tabela
    printf "%-15s %-20s %-20s %-10s\n" "ID" "FILENAME" "DELETION_DATE" "SIZE"
    echo "------------------------------------------------------------"
    
    local match_count=0

    # Processa a pesquisa baseada no tipo
    case "$search_by" in

        "id")

            # Pesquisa por ID exato
            local entry=$(grep "^$pattern," "$METADATA_FILE")

            #Verifica se entry está vazia
            if [ -n "$entry" ]; then #Caso não esteja:

                #Divide a entrada do metadata nos seus campos
                IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$entry"
                
                #Mostra o resultado
                show_search_result "$id" "$original_name" "$deletion_date" "$file_size"
                match_count=$((match_count + 1)) #Contador de nº de ficheiros encontrados no recycle bin

            fi
            ;;

        "wildcard")

            #Converte wildcards para formato grep
            local grep_pattern=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/.*/g' | sed 's/\?/./g')
            
            #Pesquisa com wildcards
            while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do

                #Verifica se o original name corresponde ao serach pattern
                if echo "$original_name" | grep -qi "$grep_pattern"; then #Caso o nome corresponda ao padrão:

                    #Mostra o resultado
                    show_search_result "$id" "$original_name" "$deletion_date" "$file_size"
                    match_count=$((match_count + 1)) #Contador de nº de ficheiros encontrados no recycle bin
                fi


            #Mostra todas as linhas do ficheiro a partir da linha 2 que correspondam ao padrão
            done < <(grep -i "$grep_pattern" "$METADATA_FILE" | tail -n +2)
            ;;

        "path")

            #Pesquisa por caminho
            while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do

                #Verifica se o original path corresponde ao serach pattern
                if echo "$original_path" | grep -qi "$pattern"; then #Caso o caminho corresponda:

                    # Mostra o resultado
                    show_search_result "$id" "$original_name" "$deletion_date" "$file_size"
                    match_count=$((match_count + 1)) #Contador de nº de ficheiros encontrados no recycle bin

                fi

            #Mostra todas as linhas do ficheiro a partir da linha 2 que correspondam ao padrão
            done < <(grep -i "$pattern" "$METADATA_FILE" | tail -n +2)
            ;;

        "filename")

            # Pesquisa por nome do ficheiro
            while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
                
                #Verifica se o original name corresponde ao serach pattern
                if echo "$original_name" | grep -qi "$pattern"; then #Caso o nome corresponda:

                    # Mostra o resultado
                    show_search_result "$id" "$original_name" "$deletion_date" "$file_size"
                    match_count=$((match_count + 1)) #Contador de nº de ficheiros encontrados no recycle bin

                fi

            #Mostra todas as linhas do ficheiro a partir da linha 2 que correspondam ao padrão
            done < <(grep -i "$pattern" "$METADATA_FILE" | tail -n +2)
            ;;
    esac

    #Mostra o resumo dos resultados:
    #Verifica se foram encontrado resultados
    if [ "$match_count" -eq 0 ]; then #Caso não tenham sido encontrados resultados:

        # Mensagem a informar que não foram encontrados resultados
        echo "${RED}No matches found for: '$pattern ${NC}'"

    else #Caso tenham sido encontrados resultados:

        # Mensagem com o número de resultados encontrados
        echo "${GREEN}Found $match_count match(es)"

    fi

    return 0
}

#################################################
# Function: show_search_result
# Description: Shows formatted search result
# Parameters: $1 - ID, $2 - filename, $3 - deletion date, $4 - file size
# Returns: 0 on success
#################################################
show_search_result() {

    local id="$1" #ID
    local original_name="$2" #filename
    local deletion_date="$3" #deletion date
    local file_size="$4" #file size

    #Formata valores para display
    local display_id="${id:0:10}..."
    local display_name="$original_name"
    [ ${#display_name} -gt 18 ] && display_name="${display_name:0:15}..."
    
    local display_date="${deletion_date:0:16}"
    
    local display_size
    if [ "$file_size" -lt 1024 ]; then #Caso o tamanho seja menor que 1KB:
    
        #Mostra o tamanho em bytes
        display_size="${file_size}B"
        
    elif [ "$file_size" -lt 1048576 ]; then #Caso o tamanho seja menor que 1MB:
    
        #Converte para KB e mostra
        display_size="$((file_size / 1024))KB"
        
    else #Caso o tamanho seja maior ou igual a 1MB:
    
        #Converte para MB e mostra
        display_size="$((file_size / 1048576))MB"
    fi

    #Mostra a linha formatada da tabela
    printf "%-15s %-20s %-20s %-10s\n" "$display_id" "$display_name" "$display_date" "$display_size"
}


#################################################
# Function: display_help
# Description: Shows comprehensive usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    #Mostra o menu de ajuda formatado com cores
    cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
    $0 [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file>       Move file/directory to recycle bin
    list                List all items in recycle bin
    list --detailed     List with detailed information
    restore <id>        Restore file by ID
    search <pattern>    Search for files by name, path or wildcard
    empty               Empty recycle bin permanently
    empty <id>          Delete specific file by ID
    empty --force       Empty without confirmation
    help                Display this help message

EXAMPLES:
    $0 delete myfile.txt
    $0 list
    $0 list --detailed
    $0 restore 1696234567_abc123
    $0 search "*.txt"
    $0 empty
    $0 empty 1696234567_abc123
    $0 empty --force

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
    #Inicializa o recycle bin
    initialize_recyclebin

    #Processa os argumentos da linha de comandos
    case "$1" in
        delete)
            shift
            delete_file "$@"
            ;;
        list)
            list_recycled "$2"
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
            #Verifica se foi passado um ID específico ou a flag --force
            if [ -n "$2" ] && [ "$2" != "--force" ]; then #Caso tenha sido passado um argumento que não é --force:

                #Elimina ficheiro específico por ID
                empty_specific_file "$2"
            else #Caso contrário:

                #Elimina todos os ficheiros
                empty_recyclebin "$2"
            fi
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            #Mensagem de erro para opção inválida
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

#Executa a função main com todos os argumentos
main "$@"
