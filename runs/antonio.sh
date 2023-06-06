#!/bin/bash

# Function to calculate the average of an array
function calculate_average() {
  local total=0
  local count=0
  for value in "${@}"; do
    total=$(echo "scale=12; $total + $value" | bc)
    ((count++))
  done
  echo "scale=12; $total / $count" | bc
}

# Script arguments
printf "Argumentos - host:%s, n_samples:%d, compilation_flags in:%s\n" "$1" "$2" "$3"

cabecera="Maquina,VCodigo,Banderas de compilacion,Numero de Sitios,Numero de Threads,Samples,Promedio[s],Stdev[s],ErrRel,Metrica[ms]"
results_file="results/results.csv"

# If the results file does not exist, add a header
if [ ! -f "$results_file" ]; then
  echo "$cabecera" > "$results_file"
fi

# Read compilation flags into an array
mapfile -t flags_array < "$3"

# Loop through compilation flags and grid sizes
for flags in "${flags_array[@]}"; do
  for grid_size in 256 512 1024; do
    L=$grid_size
    n_points=$(echo "scale=12; $L ^ 2" | bc)

    for threads in 1 2 4 8 16; do
      # Modify the Makefile with the compilation flags
      modified_flags="CFLAGS = $flags -DL=$grid_size -DNUM_THREADS=$threads"
      sed -i -e "s/CFLAGS = .*/$modified_flags/" Makefile

      # Compile
      make clean
      make tiny_ising

      # Run simulations and store the total simulation times in an array
      total_s_time_array=()
      for ((i = 1; i <= "$2"; i++)); do
        total_s_time=$(OMP_PROC_BIND=true ./tiny_ising | grep "Total Simulation Time" | grep -Eo '[0-9]+\.[0-9]+')
        total_s_time_array+=("$total_s_time")
      done

      # Calculate average, standard deviation, and metric
      average=$(calculate_average "${total_s_time_array[@]}")
      stdev=$(printf '%s\n' "${total_s_time_array[@]}" | awk -v avg="$average" '{ diff = $1 - avg; sum += diff * diff } END { print sqrt(sum / (NR - 1)) }')
      err_rel_porc=$(echo "scale=12; 100 * ($stdev / $average)" | bc)
      metrica=$(echo "scale=12; $n_points / ($average * 1000)" | bc)

      # Write the results to the CSV file
      host=$(hostname)
      resultado="$host,$1,$flags,$n_points,$threads,$2,$average,$stdev,$err_rel_porc,$metrica"
      echo "$resultado" >> "$results_file"
    done
  done
done