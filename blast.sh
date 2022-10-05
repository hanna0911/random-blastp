#!/bin/bash


# 将原序列文件protein/VIM.fasta的内容读出到header, protein_string中
i=0
while read line; do 
    if [ "$i" -eq 0 ]; then
        header="$line"
    else
        protein_string+="$line"
    fi    
    i=$((i+1))
done < protein/VIM.fasta

# 将protein_string字符串按字符存到protein_array数组中
while read -n 1 char ; do
    protein_array+=($char)
done <<< "$protein_string"

# 打乱函数（就地洗牌）
function shuffle {
    local i tmp size rand
    size=${#protein_array[*]}
    for ((i=size-1; i>0; i--)); do
        rand=$(( $RANDOM % (i + 1) ))
        # swap
        tmp=${protein_array[i]}
        protein_array[i]=${protein_array[rand]}
        protein_array[rand]=$tmp
    done
}

# 隔70个字符就换行（fasta文件序列输出美观）
function endline {
    local i size remainer
    size=${#protein_array[*]}
    for ((i=0; i<size; i++)); do
        new_protein_string+="${protein_array[$i]}"
        remainer=$(( $i % 70 )) 
        if [ $remainer == 69 ]; then
            new_protein_string+="\n"
        fi
    done
}

[ ! -d clone ] && mkdir clone  # 随机序列生成在clone文件夹中


total=10  # 生成的随机序列个数为10个

# 将原蛋白序列随机打乱生成total=10个，并存储到fasta文件中
for ((i=0; i<$total; i++)); do
    
    # 将原蛋白序列随机打乱
    shuffle
    new_header=">CLONE$i"
    new_protein_string=""
    output="clone/clone$i.fasta"
    
    # 按fasta格式要求存储到文件
    endline
    echo "${new_header}" > "$output"
    echo -e "${new_protein_string}" >> "$output"

done 


# 用blastp进行序列比对，并将结果生成到文件
function blast {
    query="clone/clone$1.fasta"
    subject="clone/clone$2.fasta"
    output_blastp="output/blastp_$1_$2"
    blastp -query $query -subject $subject -out $output_blastp  # 核心blastp命令
}


# 读取并解析blastp生成的结果文件
function read_result {

    local i hit result_file valid_info score expect

    result_file="output/blastp_$1_$2"
    valid_info=`grep -A 3 "> CLONE$2" $result_file`  # 获取"> CLONE$2"关键词往后3行内容

    # 仅分析结果文件中的Score和Expect
    hit=0  # 记录query和subject序列是否有hit
    while read line; do 
        if grep -q "Score" <<< "$line"; then
            hit=1
            IFS=' ' read -r -a info_array <<< "$line"
            score=${info_array[2]}  # Score
            IFS=',' read -r -a expect_array <<< "${info_array[7]}"
            expect=${expect_array[0]}  # Expect
        fi    
        i=$((i+1))
    done <<< "$valid_info"

    # 输出比对的Score和Expect结果
    if [ $hit -eq 1 ]; then 
        echo "CLONE$1 vs CLONE$2: Score = $score, Expect = $expect"
    else
        echo "CLONE$1 vs CLONE$2: No hit"
    fi
}


# 对生成的total=10个随机序列两两之间进行blast比对并读取解析结果
for ((i=0; i<$total-1; i++)); do
    for ((j=i+1; j<$total; j++)); do
        blast $i $j  # blast比对
        read_result $i $j  # 读取解析结果
    done
done
