"""
Форматы файлов:
файлы bin+hdr - запись сигналов (бинарный + текстовый файл)
файлы csv, pul, ton, txt - метки в ТЕКСТОВОМ формате
xml - пока не требуется читать

Для всех сигналов ниже нужно также построить спектры.
Желательно вынести повторяющийся код в функции
и вызывать для каждого нового сигнала.
"""


using Plots, Dates, CSV, DataFrames, FFTW
include("src/Readers.jl")

using .Readers





function drawEkg(plot, channels, i, qrsMarks, fs, neeedQrs=true)
chKey = keys(channels)[i]

data = channels[chKey]
yLabel = minimum(data) 

times = (0:length(data)-1) ./ fs



if neeedQrs
    qx, qy = [], []
    rx, ry = [], []
    sx, sy = [], []
    fx, forms = [], []


    for row in eachrow(qrsMarks)
        xQ = row[1]
        xS = row[2]
        

        segment = data[xQ:xS]
        xR = argmax(segment) + xQ - 1

        push!(qx, (xQ-1)/fs)
        push!(qy, data[xQ])
        push!(rx, (xR-1)/fs)
        push!(ry, data[xR])
        push!(sx, (xS-1)/fs)
        push!(sy, data[xS])
        push!(forms, string(row[3]))
        push!(fx, (xR-1)/fs)
        
        
    
    end
    fy = fill(yLabel - 500, length(fx))
    scatter!(plot, qx, qy, label="Q($chKey)", color=:red)
    scatter!(plot, rx, ry, label="R($chKey)", color=:green)
    scatter!(plot, sx, sy, label="S($chKey)", color=:blue)
    annotate!(plot, collect(zip(fx, fy, text.(forms, 8, :center, :black))))
end

plot!(plot, times, data, label="ECG($chKey)")


end



function normalizeQrs(qrsTable, istart, len)
    qrsMarks = filter(row -> row[1] >= istart && row[2] < istart + len, qrsTable)
    qrsMarks[!,1] .-= istart - 1
    qrsMarks[!,2] .-= istart - 1
    return qrsMarks
end


function drawSpectre(plot,signal, fs)
    L = length(signal)
    centeredSignal = signal .- (sum(signal) / L)
    spectrum = abs.(fft(centeredSignal))
    halfL = div(L, 2)
    y = spectrum[1:halfL]
    x = (0:halfL-1) .* (fs / L)
    plot!(plot, x, y, title="Спектр", xlabel="Частота, Гц", ylabel="Мощность", label="FFT", color=:black)
end


function analyzeAnomaly(aTable, qrsTable, len, anomalyName)
    anomalyStart = aTable.tbeg[1] - div(len,2)
    samples = anomalyStart : anomalyStart + len - 1
    channels, fs = Readers.readbin("data/ECG/8s001456/8s001456.bin", samples)
    normalizedAnomalyQrs = normalizeQrs(qrsTable, anomalyStart, len)
    anomalyPlot = plot(layout = (2, 1),xlabel = "Время, с.", ylabel = "Амплитуда", title = "$anomalyName", legend=:outerright)
    drawEkg(anomalyPlot[1], channels, 1, normalizedAnomalyQrs, fs)
    drawSpectre(anomalyPlot[2], channels[1], fs )
end



istart = 6235000
len = 2000
samples = istart : istart + len - 1
channels, fs, timestart, units = Readers.readbin("data/ECG/8s001456/8s001456.bin", samples)


qrsTable = CSV.read("data/ECG/8s001456/QRS.csv", DataFrame)
normalizedQrs = normalizeQrs(qrsTable, istart, len)

eKgPlot = plot(layout = (2, 1),xlabel = "Время, с.", ylabel = "Амплитуда", title = "ЭКГ", legend=:outerright)
drawEkg(eKgPlot[1], channels, 1, normalizedQrs, fs)
drawEkg(eKgPlot[2], channels, 2, normalizedQrs, fs)



bradiTable = CSV.read("data/ECG/8s001456/bradi.csv", DataFrame)
analyzeAnomaly(bradiTable, qrsTable, len, "Брадиаритмия")

ischemiaTable = CSV.read("data/ECG/8s001456/ischemia.csv", DataFrame)
analyzeAnomaly(ischemiaTable, qrsTable, len, "Ишемия")


arrTable = CSV.read("data/ECG/8s001456/arrS_S.csv", DataFrame)
analyzeAnomaly(arrTable, qrsTable, len, "Аритмия")








"""
ECG
Берем любые пару сигналов.
Показать ЭКГ с метками QRS.
Далее, для каждого файла меток arr*, bradi, ischemia - взять первую метку
и показать на графике её вместе с фрагментом сигнала ЭКГ,
который ей соответствует по позиции.
"""



"""
All
Берем сигналы движения по трем осям (MoveX, MoveY, MoveZ)
Метки не нужны
"""

"""
Breath
Метки Breath.csv накладываем на сигнал дыхания Breath.
метки SPO2.csv - на сигнал оксигенации SPOSoft.
Показываем оба сигнала синхронно.
Фрагмент должен находится внутри интервала сна (файл Sleep).
"""

"""
Oxy
Показываем только сигналы OxyR, OxyIr, SPOSoft
Накладываем метки SPO2 на сигнал SPOSoft.
"""

"""
Pressure
Для начала надо найти фрагмент,
где есть измерение АД - по наличию сигнала давления
(невалидные значения меньше нуля)
*_table_ad.txt - можно пока не трогать
метки *.pls наложить на сигнал давления (треугольной формы)
метки *.ton и наложить на сигнал тонов
"""
