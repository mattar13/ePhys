

#TODO: Eventually I want to add all filter functions into a single function 

"""
This function applies a n-pole lowpass filter
"""
function lowpass_filter(trace::Experiment; freq=50.0, pole=8)

    responsetype = Lowpass(freq; fs=1 / trace.dt)
    designmethod = Butterworth(8)
    digital_filter = digitalfilter(responsetype, designmethod)
    data = deepcopy(trace)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            #never adjust the stim
            data.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
    return data
end

function lowpass_filter!(trace::Experiment; freq=50.0, pole=8)

    responsetype = Lowpass(freq; fs=1 / trace.dt)
    designmethod = Butterworth(pole)
    digital_filter = digitalfilter(responsetype, designmethod)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            trace.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
end

lowpass_filter(trace::Experiment, freq; pole=8) = lowpass_filter(trace; freq=freq, pole=pole)

function highpass_filter(trace::Experiment; freq=0.01, pole=8)

    responsetype = Highpass(freq; fs=1 / trace.dt)
    designmethod = Butterworth(8)
    digital_filter = digitalfilter(responsetype, designmethod)
    data = deepcopy(trace)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            #never adjust the stim
            data.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
    return data
end

function highpass_filter!(trace::Experiment; freq=0.01, pole=8)

    responsetype = Highpass(freq; fs=1 / trace.dt)
    designmethod = Butterworth(pole)
    digital_filter = digitalfilter(responsetype, designmethod)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            trace.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
end

highpass_filter(trace::Experiment, freq; pole=8) = highpass_filter(trace; freq=freq, pole=pole)

function notch_filter(trace::Experiment; center=60.0, std=30.0)
    digital_filter = iirnotch(center, std, fs=1 / trace.dt)
    data = deepcopy(trace)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            #never adjust the stim
            data.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
    return data
end

function notch_filter!(trace::Experiment; center=60.0, std=10.0)
    digital_filter = iirnotch(center, std, fs=1 / trace.dt)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            trace.data_array[swp, :, ch] .= filt(digital_filter, trace[swp, :, ch])
        end
    end
end

function cwt_filter(trace::Experiment; wave=cDb2, β=2, dual_window=NaiveDelta(), period_window::Tuple{Int64,Int64}=(1, 9))
    data = deepcopy(trace)
    for swp = 1:size(trace, 1)
        for ch = 1:size(trace, 3)
            c = wavelet(wave, β=β)
            y = ContinuousWavelets.cwt(trace[swp, :, ch], c)
            reconstruct = zeros(size(y))
            reconstruct[:, period_window[1]:period_window[2]] .= y[:, period_window[1]:period_window[2]]
            data.data_array[swp, :, ch] .= ContinuousWavelets.icwt(reconstruct, c, dual_window) |> vec
        end
    end
    data
end

function cwt_filter!(trace::Experiment{T}; wave=cDb2, β::Int64=2, 
    period_window::Tuple{Int64,Int64} = (1, 9), 
    level_window::Tuple{T, T} = (-Inf, Inf),
    return_cwt = false
) where T <: Real
    c = wavelet(wave, β=β)
    if return_cwt
        cwt = Matrix{Matrix{T}}(undef, size(trace,1), size(trace,3))
        for swp = 1:size(trace, 1), ch = 1:size(trace, 3)
            cwt[swp, ch] = ContinuousWavelets.cwt(trace[swp, :, ch], c)
        end
        return cwt
    else
        for swp = 1:size(trace, 1), ch = 1:size(trace, 3)
            y = ContinuousWavelets.cwt(trace[swp, :, ch], c)
            reconstruct = zeros(size(y))
            #if period_window[end] == Inf
            #    period_window = 
            if !any(period_window .== -1)
                reconstruct[:, period_window[1]:period_window[2]] .= y[:, period_window[1]:period_window[2]]
                trace.data_array[swp, :, ch] .= ContinuousWavelets.icwt(reconstruct, c, PenroseDelta()) |> vec
            else
                #zero all numbers outside of the level window
                outside_window = findall(level_window[1] .< y .< level_window[2])
                reconstruct[:, period_window[1]:period_window[2]] .= y[:, period_window[1]:period_window[2]]
                trace.data_array[swp, :, ch] .= ContinuousWavelets.icwt(reconstruct, c, PenroseDelta()) |> vec
            
            end
        end
    end
end

"""

"""
function dwt_filter(trace::Experiment; wave=WT.db4, period_window::Tuple{Int64,Int64}=(1, 8), direction = :bidirectional)
    #In this case we have to limit the analyis to the window of dyadic time
    #This means that we can only analyze sizes if they are equal to 2^dyadic
    #We can fix this by taking a 
    data = deepcopy(trace)
    dyad_n = trunc(Int64, log(2, size(data, 2)))
    println(2^dyad_n)
    println(length(trace.t) - 2^dyad_n+1)
    if period_window[2] > dyad_n
        println("Period Window larger than dyad")
        period_window = (period_window[1], dyad_n)
    end
    for swp = 1:size(data, 1), ch = 1:size(data, 3)
        if direction == :forward
            x = data[swp, 1:2^dyad_n, ch]
            xt = dwt(x, wavelet(wave), dyad_n)
            reconstruct = zeros(size(xt))
            reconstruct[2^period_window[1]:2^(period_window[2])] .= xt[2^period_window[1]:2^(period_window[2])]
            data.data_array[swp, 1:2^dyad_n, ch] .= idwt(reconstruct, wavelet(wave))
        elseif direction == :reverse
            start_idx = length(trace.t) - (2^dyad_n) + 1
        
            x = data[swp, start_idx:length(data), ch]
            xt = dwt(x, wavelet(wave), dyad_n)
            reconstruct = zeros(size(xt))
            reconstruct[2^period_window[1]:2^(period_window[2])] .= xt[2^period_window[1]:2^(period_window[2])]
            data.data_array[swp, start_idx:length(data), ch] .= idwt(reconstruct, wavelet(wave))
        elseif direction == :bidirectional
            #do the reconstruction in the forward direction
            x = data[swp, 1:2^dyad_n, ch]
            xt = dwt(x, wavelet(wave), dyad_n)
            reconstruct_for = zeros(size(xt))
            reconstruct_for[2^period_window[1]:2^(period_window[2])] .= xt[2^period_window[1]:2^(period_window[2])]
        
            #Do the reconstruction in the reverse direction
            start_idx = length(trace.t) - (2^dyad_n) + 1
            x = data[swp, start_idx:length(data), ch]
            xt = dwt(x, wavelet(wave), dyad_n)
            reconstruct_rev = zeros(size(xt))
            reconstruct_rev[2^period_window[1]:2^(period_window[2])] .= xt[2^period_window[1]:2^(period_window[2])]
        
            data.data_array[swp, start_idx:length(data), ch] .= idwt(reconstruct_rev, wavelet(wave)) #We want to do reverse first 
            data.data_array[swp, 1:start_idx-1, ch] .= idwt(reconstruct_for, wavelet(wave))[1:start_idx-1] #And use the forward to fill in the first chunk
        end
    end
    data
end

"""
This is from the adaptive line interface filter in the Clampfit manual

This takes notch filters at every harmonic

#Stimulus artifacts have a very specific harmonic
250, 500, 750, 1000 ... 250n
"""
function EI_filter(trace; reference_filter=60.0, bandpass=10.0, cycles=5)
    data = deepcopy(trace)
    for cycle in 1:cycles
        notch_filter!(data, center=reference_filter * cycle, std=bandpass)
    end
    return data
end

function EI_filter!(trace; reference_filter=60.0, bandpass=10.0, cycles=5)
    for cycle in 1:cycles
        notch_filter!(trace, center=reference_filter * cycle, std=bandpass)
    end
end

function normalize(trace::Experiment; rng=(-1, 0))
    data = deepcopy(trace)
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            data[swp, :, ch] .= (trace[swp, :, ch] ./ minimum(trace[swp, :, ch], dims=2))
        end
    end
    return data
end

function normalize!(trace::Experiment; rng=(-1, 0))
    for swp in 1:size(trace, 1)
        for ch in 1:size(trace, 3)
            if rng[1] < 0
                trace.data_array[swp, :, ch] .= (trace[swp, :, ch] ./ minimum(trace[swp, :, ch], dims=2))
            else
                trace.data_array[swp, :, ch] .= (trace[swp, :, ch] ./ maximum(trace[swp, :, ch], dims=2))
            end
        end
    end
end

function rolling_mean(trace::Experiment; window::Int64=10)
    data = deepcopy(trace)
    for swp in 1:size(trace, 1), ch in 1:size(trace, 3)
        for i in 1:window:size(data, 2)-window
            data.data_array[swp, i, ch] = sum(data.data_array[swp, i:i+window, ch])/window
        end
    end
    return data
end