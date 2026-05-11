#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Please provide a dataset file."
    echo "Usage: ./profiler.sh <dataset.csv>"
    exit 1
fi

DATASET=$1


if [ ! -f "$DATASET" ]; then
    echo "Error: File '$DATASET' not found!"
    exit 1
fi

echo "--------------------------------------------------------------------------------------------"
echo "✅ File '$DATASET' loaded successfully."
echo "🔍 Starting Full Dataset Profiling..."
echo "--------------------------------------------------------------------------------------------"


CLEAN_DATA="temp_cleaned.csv"
awk -F'"' -v OFS='' '{ sub(/\r$/, ""); for (i=2; i<=NF; i+=2) gsub(",", " ", $i); print $0 }' "$DATASET" > "$CLEAN_DATA"

HEADER_LINE=$(head -n 1 "$CLEAN_DATA")
NUM_COLUMNS=$(echo "$HEADER_LINE" | awk -F',' '{print NF}')

echo "📊 Dataset contains $NUM_COLUMNS columns."
echo "--------------------------------------------------------------------------------------------"

echo "⚙️ Analyzing columns..."
printf "%-15s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n" "Column Name" "Type" "Missing" "Unique" "Min" "Max" "Mean"
echo "--------------------------------------------------------------------------------------------"

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

    printf "%-15s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n" "$COL_NAME" "$D_TYPE" "$MISSING" "$UNIQUE" "$MIN_VAL" "$MAX_VAL" "$MEAN_VAL"
done
echo "--------------------------------------------------------------------------------------------"


rm "$CLEAN_DATA"