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
    # Create ~/.recycle_bin/ directory structure if not exists
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
        # Create subdirectory files/ for storing deleted items
        mkdir -p "$FILES_DIR"
        
        # Initialize metadata.db with CSV header
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        
        # Create default config file with settings
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
        
        # Create empty recyclebin.log file
        touch "$LOG_FILE"
        
        echo -e "${GREEN}Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
        log_message "Recycle bin initialized"
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
    local files_to_process=()

    # Accept one or more file/directory paths as arguments
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No files specified${NC}"
        echo "Usage: $0 delete <file1> [file2 ...]"
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

    # Provide user feedback (success/failure messages)
    if [ $# -gt 1 ]; then
        echo
        if [ "$success_count" -gt 0 ]; then
            echo -e "${GREEN} $success_count item(s) moved to recycle bin${NC}"
        fi
        if [ "$fail_count" -gt 0 ]; then
            echo -e "${RED} $fail_count item(s) failed to delete${NC}"
        fi
    fi

    return $((fail_count > 0))
}


#################################################
# Function: delete_single_file
# Description: Moves a single file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_single_file() {
    local file_path="$1"

    # Validate that files exist before deletion
    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: No file specified${NC}"
        return 1
    fi

    # File doesn't exist error handling
    if [ ! -e "$file_path" ]; then
        echo -e "${RED}Error: File '$file_path' does not exist${NC}"
        return 1
    fi

    # Get absolute path and check for recycle bin itself
    local original_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")
    local recycle_bin_path=$(realpath "$RECYCLE_BIN_DIR" 2>/dev/null)
    
    # Cannot delete recycle bin itself
    if [ "$original_path" = "$recycle_bin_path" ] || [[ "$original_path" == "$recycle_bin_path"/* ]]; then
        echo -e "${RED}Error: Cannot delete the recycle bin itself or its contents${NC}"
        return 1
    fi

    # No read/write permissions error handling
    if [ ! -r "$file_path" ]; then
        echo -e "${RED}Error: No read permission for '$file_path'${NC}"
        return 1
    fi

    if [ ! -w "$(dirname "$file_path")" ]; then
        echo -e "${RED}Error: No write permission for directory of '$file_path'${NC}"
        return 1
    fi

    # Check disk space before moving
    local file_size=0
    if [ -d "$file_path" ]; then
        file_size=$(du -sb "$file_path" 2>/dev/null | cut -f1 || echo "0")
    else
        file_size=$(stat -c "%s" "$file_path" 2>/dev/null || echo "0")
    fi

    local available_space=$(df "$FILES_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "$file_size" -gt "$available_space" ]; then
        echo -e "${RED}Error: Insufficient disk space to move '$file_path' to recycle bin${NC}"
        return 1
    fi

    # Extract and store metadata
    local filename=$(basename "$file_path")
    local deletion_date=$(date '+%Y-%m-%d %H:%M:%S')
    local permissions=$(stat -c "%a" "$file_path" 2>/dev/null || echo "644")
    local owner=$(stat -c "%U:%G" "$file_path" 2>/dev/null || echo "$(whoami):$(id -gn)")
    
    # Determine file type and get accurate size
    local file_type="file"
    if [ -d "$file_path" ]; then
        file_type="directory"
        # For directories, use du to get total size including contents (recursive deletion support)
        file_size=$(du -sb "$file_path" 2>/dev/null | cut -f1 || echo "0")
        
        # Check if directory is empty (optional, but good practice)
        if [ ! -z "$(ls -A "$file_path" 2>/dev/null)" ]; then
            echo -e "${YELLOW}Note: Directory '$filename' contains files and will be moved recursively${NC}"
        fi
    else
        file_size=$(stat -c "%s" "$file_path" 2>/dev/null || echo "0")
    fi

    # Generate unique ID for each deleted item
    local unique_id=$(generate_unique_id)

    # Move files to ~/.recycle_bin/files/ with unique ID as filename
    echo -e "${YELLOW}Moving '$filename' to recycle bin...${NC}"
    
    if mv "$file_path" "$FILES_DIR/$unique_id" 2>/dev/null; then
        # Append metadata entry to metadata.db
        echo "$unique_id,$filename,$original_path,$deletion_date,$file_size,$file_type,$permissions,$owner" >> "$METADATA_FILE"
        
        # Log all operations to recyclebin.log
        log_message "Deleted: $filename (ID: $unique_id) from $original_path - Size: $file_size bytes"
        
        # Provide user feedback
        echo -e "${GREEN} Successfully moved to recycle bin: $filename${NC}"
        echo -e "${BLUE}  File ID: $unique_id${NC}"
        echo -e "${BLUE}  Original location: $original_path${NC}"
        echo -e "${BLUE}  Size: $file_size bytes${NC}"
        echo -e "${BLUE}  Type: $file_type${NC}"
        
        return 0
    else
        echo -e "${RED}Error: Failed to move '$filename' to recycle bin${NC}"
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
    local search_term="$1"
    
    # Accept file ID or filename as parameter
    if [ -z "$search_term" ]; then
        echo -e "${RED}Error: No file ID or filename specified${NC}"
        echo "Usage: $0 restore <ID_or_filename>"
        return 1
    fi

    # Search metadata for matching entry
    local entry
    if [[ "$search_term" =~ ^[0-9]+_[a-z0-9]+$ ]]; then
        # Search by ID (format: timestamp_random)
        entry=$(grep "^$search_term," "$METADATA_FILE")
    else
        # Search by filename (case-insensitive, partial match)
        entry=$(grep -i ",$search_term," "$METADATA_FILE" | head -n 1)
        if [ -z "$entry" ]; then
            # Try matching the original name field specifically
            entry=$(awk -F, -v pattern="$search_term" '
                tolower($2) ~ tolower(pattern) {print; exit}
            ' "$METADATA_FILE")
        fi
    fi

    # File ID not found error handling
    if [ -z "$entry" ]; then
        echo -e "${RED}Error: File '$search_term' not found in recycle bin${NC}"
        return 1
    fi

    # Parse metadata entry
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$entry"

    # If user searched by filename but multiple matches exist, show warning
    if [[ ! "$search_term" =~ ^[0-9]+_[a-z0-9]+$ ]]; then
        local match_count=$(grep -i ",$original_name," "$METADATA_FILE" | wc -l)
        if [ "$match_count" -gt 1 ]; then
            echo -e "${YELLOW}Warning: Multiple files named '$original_name' found in recycle bin${NC}"
            echo -e "${YELLOW}Using the most recently deleted one. Use specific ID for exact match.${NC}"
        fi
    fi

    # Check if file exists in recycle bin storage
    if [ ! -e "$FILES_DIR/$id" ]; then
        echo -e "${RED}Error: File '$original_name' not found in recycle bin storage${NC}"
        return 1
    fi

    # Handle restoration conflicts
    
    # If original path no longer exists, create parent directories
    local parent_dir=$(dirname "$original_path")
    if [ ! -d "$parent_dir" ]; then
        echo -e "${YELLOW}Original directory doesn't exist. Creating: $parent_dir${NC}"
        if ! mkdir -p "$parent_dir"; then
            echo -e "${RED}Error: Failed to create directory '$parent_dir'${NC}"
            return 1
        fi
    fi

    # Check if destination directory is writable
    if [ ! -w "$parent_dir" ]; then
        echo -e "${RED}Error: Permission denied. Cannot write to '$parent_dir'${NC}"
        return 1
    fi

    # Check disk space issues
    local available_space=$(df "$parent_dir" | awk 'NR==2 {print $4}')
    if [ "$file_size" -gt "$available_space" ]; then
        echo -e "${RED}Error: Insufficient disk space to restore '$original_name'${NC}"
        echo -e "${RED}Required: $file_size bytes, Available: $available_space bytes${NC}"
        return 1
    fi

    # If file already exists at original path, ask user for action
    local restore_path="$original_path"
    local conflict_resolved=false
    
    if [ -e "$original_path" ]; then
        echo -e "${YELLOW}File already exists at: $original_path${NC}"
        echo "Choose an option:"
        echo "1) Overwrite existing file"
        echo "2) Restore with modified name (append timestamp)"
        echo "3) Cancel operation"
        
        while [ "$conflict_resolved" = false ]; do
            read -p "Enter your choice (1-3): " choice
            
            case $choice in
                1)
                    # Overwrite existing file
                    if rm -rf "$original_path" 2>/dev/null; then
                        restore_path="$original_path"
                        conflict_resolved=true
                    else
                        echo -e "${RED}Error: Cannot overwrite file. Permission denied.${NC}"
                        return 1
                    fi
                    ;;
                2)
                    # Restore with modified name (append timestamp)
                    local basename="${original_name%.*}"
                    local extension="${original_name##*.}"
                    local timestamp=$(date +%Y%m%d_%H%M%S)
                    
                    if [ "$extension" = "$original_name" ]; then
                        # No extension
                        restore_path="$parent_dir/${basename}_${timestamp}"
                    else
                        restore_path="$parent_dir/${basename}_${timestamp}.${extension}"
                    fi
                    
                    echo -e "${YELLOW}Restoring as: $(basename "$restore_path")${NC}"
                    conflict_resolved=true
                    ;;
                3)
                    # Cancel operation
                    echo -e "${YELLOW}Restore cancelled${NC}"
                    return 1
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                    ;;
            esac
        done
    fi

    # Restore file to original absolute path
    echo -e "${YELLOW}Restoring: $original_name${NC}"
    echo -e "${BLUE}From: $FILES_DIR/$id${NC}"
    echo -e "${BLUE}To: $restore_path${NC}"

    if mv "$FILES_DIR/$id" "$restore_path"; then
        # Restore original permissions using chmod
        if ! chmod "$permissions" "$restore_path" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Could not restore original permissions${NC}"
        fi
        
        # Try to restore ownership (if running as root)
        if [ "$(id -u)" -eq 0 ] && [ -n "$owner" ]; then
            IFS=':' read -r owner_user owner_group <<< "$owner"
            chown "$owner_user:$owner_group" "$restore_path" 2>/dev/null || true
        fi

        # Remove entry from metadata.db after successful restoration
        if grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && \
           mv "${METADATA_FILE}.tmp" "$METADATA_FILE"; then
            # Provide restoration feedback
            echo -e "${GREEN} Successfully restored: $original_name${NC}"
            if [ "$restore_path" != "$original_path" ]; then
                echo -e "${GREEN} File renamed to: $(basename "$restore_path")${NC}"
            fi
            echo -e "${BLUE}Location: $restore_path${NC}"
            
            # Log restoration operations
            log_message "Restored: $original_name to $restore_path (ID: $id)"
            return 0
        else
            echo -e "${RED}Error: File restored but failed to update metadata${NC}"
            # File is restored but metadata wasn't updated - this is inconsistent state
            log_message "ERROR: File restored but metadata update failed for $original_name (ID: $id)"
            return 1
        fi
    else
        echo -e "${RED}Error: Failed to restore '$original_name'${NC}"
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
    local detailed_mode=0
    
    # Check for --detailed flag
    if [ "$1" = "--detailed" ]; then
        detailed_mode=1
    fi

    # Check if recycle bin is empty
    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]; then
        echo -e "${YELLOW}Recycle bin is empty${NC}"
        return 0
    fi

    local line_count=$(wc -l < "$METADATA_FILE")
    local item_count=$((line_count - 1))
    
    if [ "$item_count" -eq 0 ]; then
        echo -e "${YELLOW}Recycle bin is empty${NC}"
        return 0
    fi

    # Display all items currently in recycle bin
    if [ "$detailed_mode" -eq 1 ]; then
        list_detailed_view
    else
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
    local total_size=0
    local item_count=0
    
    echo -e "${BLUE}=== Recycle Bin Contents ===${NC}"
    
    # Show in formatted table with columns
    printf "%-18s %-25s %-20s %-12s\n" "ID" "FILENAME" "DELETION_DATE" "SIZE"
    printf "%s\n" "----------------------------------------------------------------"
    
    # Read metadata file and format output (skip header line)
    while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        # Skip header line
        if [ "$id" = "ID" ]; then
            continue
        fi
        
        # Unique ID (truncated for display)
        local display_id="${id:0:12}..."
        
        # Original filename (truncated if too long)
        local display_name="$original_name"
        if [ ${#display_name} -gt 23 ]; then
            display_name="${display_name:0:20}..."
        fi
        
        # Deletion date and time (format for display)
        local display_date="${deletion_date:0:16}"
        
        # File size (human-readable format: B, KB, MB, GB)
        local display_size
        if [ "$file_size" -lt 1024 ]; then
            display_size="${file_size}B"
        elif [ "$file_size" -lt 1048576 ]; then
            display_size="$((file_size / 1024))KB"
        elif [ "$file_size" -lt 1073741824 ]; then
            display_size="$((file_size / 1048576))MB"
        else
            display_size="$((file_size / 1073741824))GB"
        fi
        
        # Display the formatted row
        printf "%-18s %-25s %-20s %-12s\n" "$display_id" "$display_name" "$display_date" "$display_size"
        
        # Accumulate totals
        total_size=$((total_size + file_size))
        item_count=$((item_count + 1))
        
    done < "$METADATA_FILE"
    
    # Display total item count and total storage used
    echo "----------------------------------------------------------------"
    
    # Format total size for display
    local display_total_size
    if [ "$total_size" -lt 1024 ]; then
        display_total_size="${total_size}B"
    elif [ "$total_size" -lt 1048576 ]; then
        display_total_size="$((total_size / 1024))KB"
    elif [ "$total_size" -lt 1073741824 ]; then
        display_total_size="$((total_size / 1048576))MB"
    else
        display_total_size="$((total_size / 1073741824))GB"
    fi
    
    echo -e "${GREEN}Total items: $item_count${NC}"
    echo -e "${GREEN}Total storage used: $display_total_size${NC}"
}


#################################################
# Function: list_detailed_view
# Description: Shows full information per item
# Parameters: None
# Returns: 0 on success
#################################################
list_detailed_view() {
    local total_size=0
    local item_count=0
    local file_count=0
    local dir_count=0
    
    echo -e "${BLUE}=== Recycle Bin Contents (Detailed View) ===${NC}"
    
    # Read metadata file (skip header line)
    while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        # Skip header line
        if [ "$id" = "ID" ]; then
            continue
        fi
        
        # Count file types
        if [ "$file_type" = "file" ]; then
            ((file_count++))
        else
            ((dir_count++))
        fi
        
        # Display full information per item
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║ Item: $((item_count + 1))${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
        printf "${BLUE}║${NC} %-15s: ${GREEN}%s${NC}\n" "ID" "$id"
        printf "${BLUE}║${NC} %-15s: ${GREEN}%s${NC}\n" "Filename" "$original_name"
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Original Path" "$original_path"
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Deleted" "$deletion_date"
        
        # File size (human-readable format)
        local display_size
        if [ "$file_size" -lt 1024 ]; then
            display_size="${file_size} bytes"
        elif [ "$file_size" -lt 1048576 ]; then
            display_size="$((file_size / 1024)) KB"
        elif [ "$file_size" -lt 1073741824 ]; then
            display_size="$((file_size / 1048576)) MB"
        else
            display_size="$((file_size / 1073741824)) GB"
        fi
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Size" "$display_size"
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Type" "$file_type"
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Permissions" "$permissions"
        printf "${BLUE}║${NC} %-15s: ${YELLOW}%s${NC}\n" "Owner" "$owner"
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        
        # Accumulate totals
        total_size=$((total_size + file_size))
        item_count=$((item_count + 1))
        
    done < "$METADATA_FILE"
    
    # Display comprehensive summary
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "${GREEN}Total items: $item_count${NC}"
    echo -e "${GREEN}Files: $file_count${NC}"
    echo -e "${GREEN}Directories: $dir_count${NC}"
    
    # Format total storage used
    local display_total_size
    if [ "$total_size" -lt 1024 ]; then
        display_total_size="${total_size} bytes"
    elif [ "$total_size" -lt 1048576 ]; then
        display_total_size="$((total_size / 1024)) KB"
    elif [ "$total_size" -lt 1073741824 ]; then
        display_total_size="$((total_size / 1048576)) MB"
    else
        display_total_size="$((total_size / 1073741824)) GB"
    fi
    echo -e "${GREEN}Total storage used: $display_total_size${NC}"
    
    # Calculate average size
    if [ "$item_count" -gt 0 ]; then
        local avg_size=$((total_size / item_count))
        local display_avg_size
        if [ "$avg_size" -lt 1024 ]; then
            display_avg_size="${avg_size} bytes"
        elif [ "$avg_size" -lt 1048576 ]; then
            display_avg_size="$((avg_size / 1024)) KB"
        else
            display_avg_size="$((avg_size / 1048576)) MB"
        fi
        echo -e "${GREEN}Average item size: $display_avg_size${NC}"
    fi
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items or specific item by ID
# Parameters: 
#   $1 - (optional) "all" or specific file ID, or "--force" to skip confirmation
# Returns: 0 on success, 1 on failure
#################################################
empty_recyclebin() {
    local target="$1"
    local force_mode=0
    
    # Handle --force flag
    if [ "$target" = "--force" ]; then
        force_mode=1
        target="all"
    elif [ -z "$target" ]; then
        target="all"
    fi

    # Check if recycle bin is empty
    local line_count=$(wc -l < "$METADATA_FILE" 2>/dev/null || echo 0)
    if [ ! -f "$METADATA_FILE" ] || [ "$line_count" -le 1 ]; then
        echo -e "${YELLOW}Recycle bin is already empty${NC}"
        return 0
    fi

    # Handle specific file deletion by ID
    if [ "$target" != "all" ]; then
        empty_specific_file "$target" "$force_mode"
        return $?
    fi

    # Empty all mode
    local item_count=$((line_count - 1))
    
    # Require user confirmation before permanent deletion (unless --force)
    if [ "$force_mode" -eq 0 ]; then
        echo -e "${RED}**WARNING:** This will permanently delete all $item_count items${NC}"
        echo -e "${RED}This action cannot be undone!${NC}"
        
        read -p "Are you sure? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Force mode: Emptying recycle bin without confirmation${NC}"
    fi

    # Permanently delete files using rm -rf
    echo -e "${YELLOW}Deleting files from recycle bin...${NC}"
    if [ -d "$FILES_DIR" ] && [ "$(ls -A "$FILES_DIR" 2>/dev/null)" ]; then
        if rm -rf "$FILES_DIR"/* 2>/dev/null; then
            echo -e "${GREEN} All files deleted from recycle bin${NC}"
        else
            echo -e "${RED}Error: Failed to delete some files${NC}"
        fi
    else
        echo -e "${YELLOW}No files found in recycle bin directory${NC}"
    fi

    # Update metadata.db accordingly
    echo -e "${YELLOW}Clearing metadata...${NC}"
    if echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"; then
        echo -e "${GREEN} Metadata cleared${NC}"
    else
        echo -e "${RED}Error: Failed to clear metadata file${NC}"
        return 1
    fi

    # Display summary of deleted items
    echo -e "${GREEN} Recycle bin emptied successfully${NC}"
    echo -e "${GREEN}$item_count items permanently deleted${NC}"
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
    local file_id="$1"
    local force_mode="${2:-0}"

    # Validate input
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    # Search for the file in metadata
    local entry=$(grep "^$file_id," "$METADATA_FILE")
    if [ -z "$entry" ]; then
        echo -e "${RED}Error: File with ID '$file_id' not found in recycle bin${NC}"
        return 1
    fi

    # Parse metadata
    IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner <<< "$entry"
    
    # Require user confirmation before permanent deletion (unless force mode)
    if [ "$force_mode" -eq 0 ]; then
        echo -e "${YELLOW}About to permanently delete:${NC}"
        echo -e "  Name: $original_name"
        echo -e "  Original path: $original_path"
        echo -e "  Deleted: $deletion_date"
        echo -e "  Size: $file_size bytes"
        echo -e "${RED}This action cannot be undone!${NC}"
        
        read -p "Are you sure? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            return 1
        fi
    fi

    # Permanently delete the specific file using rm -rf
    if [ -e "$FILES_DIR/$file_id" ]; then
        if rm -rf "$FILES_DIR/$file_id"; then
            echo -e "${GREEN} File '$original_name' permanently deleted${NC}"
        else
            echo -e "${RED}Error: Failed to delete file '$original_name'${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Warning: File not found in storage, but removing from metadata${NC}"
    fi

    # Update metadata.db accordingly
    if grep -v "^$file_id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && \
       mv "${METADATA_FILE}.tmp" "$METADATA_FILE"; then
        echo -e "${GREEN} Removed from metadata database${NC}"
        
        # Display summary of deleted item
        echo -e "${GREEN} File '$original_name' permanently deleted${NC}"
        log_message "Permanently deleted: $original_name (ID: $file_id)"
        return 0
    else
        echo -e "${RED}Error: Failed to update metadata database${NC}"
        return 1
    fi
}


#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin with advanced pattern matching
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    local pattern="$1"

    # Validate input
    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: No search pattern specified${NC}"
        echo "Usage: $0 search <pattern>"
        echo "Examples:"
        echo "  $0 search \"*.txt\""
        echo "  $0 search \"report\""
        echo "  $0 search \".pdf\""
        return 1
    fi

    # Check if recycle bin exists and has content
    if [ ! -f "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE" 2>/dev/null || echo 0) -le 1 ]; then
        echo -e "${YELLOW}Recycle bin is empty${NC}"
        return 0
    fi

    echo -e "${BLUE}=== Search Results for: '$pattern' ===${NC}"
    
    local match_count=0
    
    # Display table header
    printf "%-20s %-25s %-35s %-12s %-10s\n" "ID" "FILENAME" "PATH" "SIZE" "DELETED"
    printf "%s\n" "-------------------------------------------------------------------------------------------------------------------"
    
    # Convert basic wildcard pattern to grep-compatible pattern
    local grep_pattern=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/.*/g')
    
    # Search in metadata using grep (case-insensitive)
    while IFS=',' read -r id original_name original_path deletion_date file_size file_type permissions owner; do
        # Check if pattern matches in filename or path (case-insensitive)
        if echo "$original_name" | grep -qi "$grep_pattern" || echo "$original_path" | grep -qi "$grep_pattern"; then
            # Format display values
            local display_id="${id:0:12}..."
            local display_name="$original_name"
            [ ${#display_name} -gt 22 ] && display_name="${display_name:0:19}..."
            
            local display_path="$original_path"
            [ ${#display_path} -gt 32 ] && display_path="...${original_path: -29}"
            
            local display_size
            if [ "$file_size" -lt 1024 ]; then
                display_size="${file_size}B"
            elif [ "$file_size" -lt 1048576 ]; then
                display_size="$((file_size / 1024))KB"
            else
                display_size="$((file_size / 1048576))MB"
            fi
            
            local display_date="${deletion_date:0:16}"
            
            printf "%-20s %-25s %-35s %-12s %-10s\n" "$display_id" "$display_name" "$display_path" "$display_size" "$display_date"
            match_count=$((match_count + 1))
        fi
    done < <(tail -n +2 "$METADATA_FILE")

    # Results summary
    if [ "$match_count" -eq 0 ]; then
        echo -e "${YELLOW}No matches found for: '$pattern'${NC}"
        echo -e "${YELLOW}Try a different search term or use '*' for wildcards${NC}"
    else
        echo "-------------------------------------------------------------------------------------------------------------------"
        echo -e "${GREEN}Found $match_count match(es)${NC}"
    fi

    return 0
}


#################################################
# Function: display_help
# Description: Shows comprehensive usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << EOF
    ${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}
    ${BLUE}║                LINUX RECYCLE BIN - USAGE GUIDE              ║${NC}
    ${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}

    ${GREEN}SYNOPSIS:${NC}
        $0 [OPTION] [ARGUMENTS]

    ${GREEN}DESCRIPTION:${NC}
        A comprehensive recycle bin system for Linux that safely manages file deletion
        and restoration, preserving file metadata and permissions.

    ${GREEN}AVAILABLE COMMANDS:${NC}

    ${YELLOW}  delete <file1> [file2 ...]${NC}
        Move files or directories to recycle bin
         Supports multiple files and directories
         Preserves metadata and permissions
         Handles recursive directory deletion

    ${YELLOW}  list [--detailed]${NC}
        List all items currently in recycle bin
         Compact table view (default)
         Detailed view with --detailed flag
         Shows file sizes in human-readable format

    ${YELLOW}  restore <ID_or_filename>${NC}
        Restore file from recycle bin to original location
         Accepts file ID or filename
         Handles naming conflicts automatically
         Restores original permissions and metadata

    ${YELLOW}  search <pattern>${NC}
        Search for files in recycle bin
         Searches both filename and original path
         Case-insensitive matching
         Supports wildcard patterns (*.txt, report*)

    ${YELLOW}  empty [ID] [--force]${NC}
        Permanently delete items from recycle bin
         Delete all items (default)
         Delete specific item by ID
         Skip confirmation with --force flag

    ${YELLOW}  stats${NC}
        Show recycle bin statistics
         Total items and storage usage
         Breakdown by file type
         Oldest and newest items

    ${YELLOW}  help, --help, -h${NC}
        Display this help message

    ${GREEN}COMMAND-LINE OPTIONS:${NC}

    ${YELLOW}  Global Options:${NC}
        --verbose, -v    Enable verbose output for debugging
        --version        Display script version information
        --config         Show configuration file location

    ${YELLOW}  Command-Specific Options:${NC}
        list --detailed  Show detailed information for each item
        empty --force    Skip confirmation for permanent deletion
        empty <ID>       Delete specific item by ID

    ${GREEN}USAGE EXAMPLES:${NC}

    ${BLUE}# Basic Operations:${NC}
    $0 delete document.txt                    ${GREEN}# Delete single file${NC}
    $0 delete file1.txt file2.pdf images/     ${GREEN}# Delete multiple items${NC}
    $0 list                                   ${GREEN}# List contents (compact view)${NC}
    $0 list --detailed                        ${GREEN}# List contents (detailed view)${NC}
    $0 restore 1696234567_abc123              ${GREEN}# Restore by exact ID${NC}
    $0 restore report.pdf                     ${GREEN}# Restore by filename${NC}

    ${BLUE}# Search and Management:${NC}
    $0 search "*.pdf"                         ${GREEN}# Find all PDF files${NC}
    $0 search "document"                      ${GREEN}# Search by partial name${NC}
    $0 empty                                  ${GREEN}# Empty all (with confirmation)${NC}
    $0 empty --force                          ${GREEN}# Empty all (no confirmation)${NC}
    $0 empty 1696234567_abc123                ${GREEN}# Delete specific item${NC}
    $0 stats                                  ${GREEN}# Show statistics${NC}

    ${BLUE}# Advanced Usage:${NC}
    $0 delete *.tmp                           ${GREEN}# Delete all .tmp files${NC}
    $0 search "/home/user/projects"           ${GREEN}# Find files from specific path${NC}
    $0 list | grep "document"                 ${GREEN}# Filter list output${NC}

    ${GREEN}CONFIGURATION:${NC}
    Configuration file: ~/.recycle_bin/config
    Metadata database: ~/.recycle_bin/metadata.db
    Storage location: ~/.recycle_bin/files/

    ${GREEN}TROUBLESHOOTING:${NC}
    Use 'bash -x $0 command' for debugging
    Check ~/.recycle_bin/recyclebin.log for operation logs
    Ensure script has execute permissions: chmod +x $0

    ${YELLOW}For more information, check the technical documentation.${NC}

    ${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}
    ${BLUE}║                     END OF HELP MENU                        ║${NC}
    ${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}
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
