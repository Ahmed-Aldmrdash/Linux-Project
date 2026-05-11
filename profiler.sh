#!/bin/bash

# Check if a filename is provided as an argument
if [ -z "$1" ]; then
    echo "Error: Please provide a dataset file."
    echo "Usage: ./profiler.sh <dataset.csv>"
    exit 1
fi

DATASET=$1
LOG_FILE="cleaning_log.txt"

# Validate if the file exists
if [ ! -f "$DATASET" ]; then
    echo "Error: File '$DATASET' not found!"
    exit 1
fi

echo "====================================================================================="
echo "✅ File '$DATASET' loaded successfully."
echo "🔍 Starting Full Dataset Profiling & Cleaning..."
echo "====================================================================================="

# --- ENHANCEMENT: Data Cleaning & Duplicate Removal ---
echo "🛠 Step 1: Cleaning data & removing duplicates..."
CLEAN_DATA="temp_cleaned.csv"

# Pre-processing: Remove carriage returns, handle commas, remove empty lines, and remove duplicates keeping order
awk -F'"' -v OFS='' '{ sub(/\r$/, ""); for (i=2; i<=NF; i+=2) gsub(",", " ", $i); print $0 }' "$DATASET" | awk 'NF' | awk '!seen[$0]++' > "$CLEAN_DATA"

# Calculate deleted rows for the log
ORIGINAL_COUNT=$(wc -l < "$DATASET")
CLEAN_COUNT=$(wc -l < "$CLEAN_DATA")
DELETED=$((ORIGINAL_COUNT - CLEAN_COUNT))

# Create/Update the Enhancement Log
echo "[$(date)] Dataset: $DATASET | Removed $DELETED duplicate/empty rows." >> "$LOG_FILE"
echo "✨ Cleaning complete. $DELETED rows removed. Log updated: $LOG_FILE."

# --- STEP 2: Dataset Analysis (The Profiler) ---
HEADER_LINE=$(head -n 1 "$CLEAN_DATA")
NUM_COLUMNS=$(echo "$HEADER_LINE" | awk -F',' '{print NF}')

echo "📊 Dataset contains $NUM_COLUMNS columns (after cleaning)."
echo "====================================================================================="
echo "⚙️ Analyzing columns..."
echo ""

# Create a temporary file to store the table data for perfect formatting
TABLE_FILE="temp_table.txt"

# Table Headers
echo "Column_Name|Type|Missing|Unique|Min|Max|Mean" > "$TABLE_FILE"
echo "-----------|----|-------|------|---|---|----" >> "$TABLE_FILE"

# Loop through each column to calculate statistics
for i in $(seq 1 $NUM_COLUMNS); do
    COL_NAME=$(echo "$HEADER_LINE" | awk -F',' -v col="$i" '{print $col}')
    MISSING=$(awk -F',' -v col="$i" 'NR>1 {if($col=="") count++} END {print count+0}' "$CLEAN_DATA")
    UNIQUE=$(awk -F',' -v col="$i" 'NR>1 && $col!="" {print $col}' "$CLEAN_DATA" | sort | uniq | wc -l)
    
    STATS=$(awk -F',' -v col="$i" '
    BEGIN { min=""; max=""; sum=0; count=0; is_num=1 }
    NR>1 && $col!="" {
        if ($col !~ /^-?[0-9]*\.?[0-9]+$/) {
            is_num=0 
        } else {
            count++
            sum += $col
            if (min=="" || $col < min) min=$col
            if (max=="" || $col > max) max=$col
        }
    }
    END {
        dtype = (is_num == 1) ? "Numeric" : "String"
        if (is_num == 1 && count > 0) {
            printf "%s,%s,%s,%.2f", dtype, min, max, (sum/count)
        } else {
            printf "%s,-,-,-", dtype
        }
    }' "$CLEAN_DATA")

    IFS=',' read D_TYPE MIN_VAL MAX_VAL MEAN_VAL <<< "$STATS"

    # Append row data to the table file separated by '|'
    echo "$COL_NAME|$D_TYPE|$MISSING|$UNIQUE|$MIN_VAL|$MAX_VAL|$MEAN_VAL" >> "$TABLE_FILE"
done

# Print the table beautifully using 'column' command
column -t -s '|' "$TABLE_FILE"

echo ""
echo "====================================================================================="
# Cleanup temporary files
rm "$CLEAN_DATA" "$TABLE_FILE"