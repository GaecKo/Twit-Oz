functor
import
	Application
	Browser
	Open
	OS
	Property
	QTk at 'x-oz://system/wp/QTk.ozf'
	System
define
	% to make life easier...
	Print = System.showInfo

	% For file opening
	class TextFile
		from Open.file Open.text
	end

	proc {Browse Buf}
		{Browser.browse Buf}
	end

	% === global var ===
	InputText
	OutputText
	Files
	Ngrams
	History
	% === === == === ===

	% binary tree operations
	fun {BTGet T K}
		case T
			of leaf then % if we've arrived at a leaf, key is not in tree
				nil
			[] tree(k: MatchedK v: MatchedV MatchedLeft MatchedRight) then
				if MatchedK > K then % key is to the left
					{BTGet MatchedLeft K}
				elseif MatchedK < K then % key is to the right
					{BTGet MatchedRight K}
				else % MatchedK == K, found key
					MatchedV
				end
			else nil
		end
	end

	fun {BTSet T K V}
		case T
			of leaf then % if we've arrived at a leaf, create a new tree
				tree(k: K v: V leaf leaf)
			[] tree(k: MatchedK v: MatchedV MatchedLeft MatchedRight) then
				if MatchedK > K then % insert k-v pair to the left
					tree(k: MatchedK v: MatchedV {BTSet MatchedLeft K V} MatchedRight)
				elseif MatchedK < K then % insert k-v pair to the right
					tree(k: MatchedK v: MatchedV MatchedLeft {BTSet MatchedRight K V})
				else % MatchedK == K, simply replace old value with new one
					tree(k: K v: V MatchedLeft MatchedRight)
				end
			else T
		end
	end


	% normalize an input string
	% this consists of replacing all non-alphanumerical characters by spaces and lowercasing them, not keeping special character but keeping numbers
	fun {Sanitize String}
		case String
			of nil then 
				nil
			
			[] H|T then
		   		if H >= 97 andthen H =< 122 then 
					H|{Sanitize T} % minuscule

		   		elseif H >= 65 andthen H =< 90 then 
					{Char.toLower H}|{Sanitize T} % majuscule

		   		elseif H >= 48 andthen H =< 57 then 
					H|{Sanitize T} % chiffre

		   		else 
					32|{Sanitize T} % autre
		   		
				end
		end
	 end

	fun {HighestProbAux Probs MaxCount MaxKey}
		case Probs
			of leaf then % if we've arrived at a leaf, key is not in tree
				[MaxKey MaxCount]
			[] tree(k: Word v: Freq MatchedLeft MatchedRight) then
				local
					MaxLeft = {HighestProbAux MatchedLeft MaxCount MaxKey}
					MaxRight = {HighestProbAux MatchedRight MaxCount MaxKey}

					MaxKeyLeft = MaxLeft.1
					MaxKeyRight = MaxRight.1

					MaxCountLeft = MaxLeft.2.1
					MaxCountRight = MaxRight.2.1
				in
					if MaxCountLeft > MaxCount andthen MaxCountLeft > MaxCountRight andthen MaxCountLeft > Freq then
						[MaxKeyLeft MaxCountLeft]
					elseif MaxCountRight > MaxCount andthen MaxCountRight > Freq then
						[MaxKeyRight MaxCountRight]
					elseif Freq > MaxCount then
						[Word Freq]
					else
						[MaxKey MaxCount]
					end
				end
			else [MaxKey MaxCount]
		end
	end


	fun {HighestProb Probs}
		{HighestProbAux Probs 0 nil} % counts always be like: > 0
	end

	fun {KeysWithProbAux Probs Prob}
		Appended
	in
		case Probs
			of leaf then % if we've arrived at a leaf, key is not in tree
				nil
			[] tree(k: Word v: Freq MatchedLeft MatchedRight) then
				Appended = {List.append {KeysWithProbAux MatchedLeft Prob} {KeysWithProbAux MatchedRight Prob}}

				if Freq == Prob then
					Word | Appended
				else
					Appended
				end
			else nil
		end
	end

	fun {KeysWithProb Probs Prob}
		{KeysWithProbAux Probs Prob}
	end

	fun {BuildNgramKeyAux I N Tokens TokenCount}
		if I == N then
			nil
		else
			{BuildNgramKeyAux I + 1 N Tokens TokenCount} # {List.nth Tokens TokenCount - I} # " "
		end
	end

	fun {BuildNgramKey N Tokens TokenCount}
		VirtualStringKey = {BuildNgramKeyAux 0 N Tokens TokenCount}
	in
		{VirtualString.toAtom VirtualStringKey}
	end

	fun {ProbsNgramAux N Tokens TokenCount}
		Key = {BuildNgramKey N Tokens TokenCount}
		Ngram = {List.nth Ngrams N}
		Probs = {BTGet Ngram Key}
	in
		if Probs \= nil then
			Probs
		elseif N == 1 then
			nil % XXX Should we make this return the most common word in the whole dataset then?
		else
			{ProbsNgramAux N - 1 Tokens TokenCount}
		end
	end

	fun {ProbsNgram N Prompt}
		SanitizedPrompt = {Sanitize Prompt}
		Tokens = {String.tokens SanitizedPrompt & }
		TokenCount = {List.length Tokens}
		PossibleN = {Value.min N TokenCount} % we can't query a trigram if we only have 2 tokens
	in
		{ProbsNgramAux PossibleN Tokens TokenCount}
	end

	fun {PredictProbs Prompt}
		MaxN = {List.length Ngrams}
	in
		{ProbsNgram MaxN Prompt}
	end

	fun {Predict Prompt}
		Probs = {PredictProbs Prompt}
	in
		{HighestProb Probs}.1
	end


	% Function launched when Predict clicked
	fun {Press Acc}
		In Out
		Probs Highest MaxKey MaxCount Entries MaxEntries MaxKeys
	in
		{InputText get(1: In)}
		if Acc == 10 then
			{AddHistory In}
			{RefreshHistory In}
		end

		if Acc \= 0 then 
			Out = {VirtualString.toString In # " " # {Predict In}}
			{OutputText set(1: {String.toAtom Out})}
			
			{InputText set(1: Out)}

			% As it's not for submission anymore, let's make it more interactive / GPT like

			% Probs = {PredictProbs In}

			% if Probs == nil then
			% 	[[nil] 0]
			% else
			% 	Highest = {HighestProb Probs}

			% 	MaxKey = Highest.1
			% 	MaxCount = Highest.2.1

			% 	MaxKeys = {KeysWithProb Probs MaxCount}

			% 	% [MaxKeys MaxCount]
			{Delay 500}
			{Press Acc-1}
			
		else 
			0
		end
	end

	proc {OnPress}
		_ = {Press 10}
	end


	% return the whole content of F
	fun {GetFileContent F}
		Content
	in 
		{F read(list: Content size: all)}
		Content
	end


	% send list of tokens to port
	proc {SendTokens P Tokens}
		case Tokens
			of H | T then % TODO check if this is TCO-able in Oz
				{Port.send P {String.toAtom H}} % TODO check if this is faster than simply working with strings
				{SendTokens P T}
			[] nil then skip
		end
	end


	% Tokens is a list of words "..."|"..."|nil|"..."|nil -> remove the nil (appart from the last one of course)
	fun {RemoveNilAux Tokens Acc} 
		case Tokens 
			of nil then Acc
			[] H|T then
				if H == nil then 
					{RemoveNilAux T Acc} 
					
				elseif H == "amp" then
					{RemoveNilAux T Acc}

				else
					{RemoveNilAux T {Append Acc [H]}}
					
				end
		end
	end

	fun {RemoveNil Tokens}
		case Tokens 
			of nil then nil 
			[] H|T then 
				if H == nil then
					{RemoveNil T}
				else 
					{RemoveNilAux Tokens.2 [Tokens.1]}
				end
		end
	end


	% Parse Tweets (whole content of a file)
	proc {ParseTweets P Tweets}
		SanitizedTweet = {Sanitize Tweets}
		Tokens = {RemoveNil {String.tokens SanitizedTweet & }} 
	in
		{SendTokens P Tokens}
	end


	% read a given part file
	% each file consists of a bunch of tweets, each on their own line
	proc {ReadPart P Name}
		F = {New TextFile init(name: Name flags: [read])}
		Tweets = {GetFileContent F}
	in
		{F close}
		{ParseTweets P Tweets}
		{Print Name}
	end


	% read each file this thread is supposed to read in the Files list
	proc {ReadThread Files FileCount P N TotalN}
		if N =< FileCount then
			{ReadPart P {List.nth Files N}} % List.nth starts counting at 1
			{ReadThread Files FileCount P N + TotalN TotalN}
		else
			{Port.send P thistokenshouldneverappearinthetweets}
		end
	end


	% run N threads for reading/parsing files
	proc {LaunchProducerThreadsAux Files P N TotalN}
		if N > 0 then
			{LaunchProducerThreadsAux Files P N - 1 TotalN}
			% thread {ReadThread Files {List.length Files} P N TotalN} end
			{ReadThread Files {List.length Files} P N TotalN}
		end
	end

	proc {LaunchProducerThreads Files P N}
		{LaunchProducerThreadsAux Files P N N}
	end


	% combine two frequency records together
	% e.g. {CombineFreqs a(lorem: 4 ipsum: 3) b(dolor: 2 ipsum: 4)} -> c(lorem: 4 ipsum: 7 dolor: 2)
	fun {CombineFreqs F1 F2}
		Sums = {Record.zip F1 F2 fun {$ Count1 Count2}
			Count1 + Count2
		end}
	in
		{Record.adjoin F2 {Record.adjoin F1 Sums}} % second record has priority over first one!
	end


	% combine two n-gram records together
	fun {CombineNgrams N1 N2}
		Sums = {Record.zip N1 N2 CombineFreqs}
	in
		{Record.adjoin N2 {Record.adjoin N1 Sums}} % second record has priority over first one!
	end


	% consume the tweet stream into an n-gram (ConsumeNgram)
	% a stream basically acts as a big list
	% go through all the words in that stream (ConsumeNgramAux)
	% for each one of those words, process the next N words (ConsumeNgramFreqs)
	% TODO thistokenshouldneverappearinthetweets -> nil? Should we even atomize words if we already atomize keys?
	fun {ConsumeNgramFreqs N S Key} % returns partial ngram record
		case S
			of Word | T then
				if Word \= thistokenshouldneverappearinthetweets then
					if N == 0 then % reached the end of the N words we had to process, previous words are the key, next word is the value
						local
							KeyAtom = {VirtualString.toAtom Key}
						in
							[KeyAtom Word]
						end
					else
						{ConsumeNgramFreqs N - 1 T Key # Word # " "}
					end
				else
					[nil nil]
				end
		end
	end

	fun {ConsumeNgram N S} % returns full ngram record
		case S
			of Word | T then
				if Word \= thistokenshouldneverappearinthetweets then
					local
						Cur = {ConsumeNgram N T}
						Ngram = {ConsumeNgramFreqs N S ""}
						Key = Ngram.1
						Word = Ngram.2.1
						PrevFreqBT = {BTGet Cur Key}
					in
						if Key \= nil then
							if PrevFreqBT == nil then % key hasn't yet appeared, create a new frequency BT
								{BTSet Cur Key tree(k: Word v: 1 leaf leaf)}
							else % key has already appeared, add to previous frequency BT
								local
									PrevFreq = {BTGet PrevFreqBT Word}
									FreqBT
								in
									if PrevFreq == nil then % word hasn't yet appeared in frequency BT, start at 1
										FreqBT = {BTSet PrevFreqBT Word 1}
									else
										FreqBT = {BTSet PrevFreqBT Word PrevFreq + 1}
									end
									{BTSet Cur Key FreqBT}
								end
							end
						else
							Cur
						end
					end
				else
					leaf
				end
		end
	end

	% consume the tweet stream into multiple n-grams
	fun {ConsumeNgramsAux N TotalN S}
		if N > TotalN then
			nil
		else
			{ConsumeNgram N S} | {ConsumeNgramsAux N + 1 TotalN S}
		end
	end

	fun {ConsumeNgrams N S}
		{ConsumeNgramsAux 1 N S}
	end

	%% HISTORY FUNCTIONS
	% Ajouter vos fonctions et procédures auxiliaires ici
	proc {RefreshHistory NewH}
		Current
	in
		{History get(
					1: Current
				)}

		{History set(
					1: {VirtualString.toString NewH # "\n" # Current}
				)}
	end

	fun {GetHistory}
		% line1\nline2...
		F = {New TextFile init(name: 'history.txt' flags: [read])}
		Content
		NewContent
	in
		%% TODO: replace \n with \n + ... + \n
		{F read(list: Content size: all)}
		Content 
	end

	proc {AddHistory Input}
		% Append to history Input|Output\n
		F = {New TextFile init(name: 'history.txt' flags: [read write])}
		WDesc
	in
		% XXX can't do this for the moment - cf. https://github.com/mozart/mozart2/pull/345
		% {F seek(whence: 'end' offset: 0)}

		{F getDesc(WDesc _)}
		{OS.lSeek WDesc 'SEEK_END' 0 _}

		{F putS(Input)}
		{F close}
	end

	fun {GetHistoryLabel}
		text(
			handle: History
			width: 20
			foreground: white
			background: c(52 53 65)
			pady: 5
			glue: nwe
		)
	end
	%% -------


	% Fetch Tweets Folder from CLI Arguments
	% See the Makefile for an example of how it is called
	fun {GetSentenceFolder}
		Args = {Application.getArgs record(
			'folder'(
				single
				type: string
				optional: false
			)
		)}
	in
		Args.'folder'
	end

	% Returns a list of the path to all files in Folder/: part_1.txt|...|nil
	fun {GetFiles Folder L} % L = {OS.getDir TweetsFolder}
		case L
			of nil then nil
			[] H|T then {VirtualString.toAtom Folder # "/" # H }|{GetFiles Folder T} % gives: 'tweets/fileX.txt'
		end
	end


	% return true if strings are equal regardless of case
	fun {Strcasecmp S1 S2}
		case S1
			of nil then
				if S2 == nil then
					true
				else
					false
				end
			[] H|T then
				if S2 == nil then
					false
				elseif {Char.toLower H} == {Char.toLower S2.1} then
					{Strcasecmp T S2.2}
				else
					false
				end
		end
	end


	% Main function that launches activities
	proc {Main}
		TweetsFolder = {GetSentenceFolder}
		Files = {GetFiles TweetsFolder {OS.getDir TweetsFolder}}
	in
		local NbThreads Description Window SeparatedWordsStream SeparatedWordsPort in
			{Property.put print foo(
				width: 1000
				depth: 1000
			)}

			% Creation de l'interface graphique

			Description=td(
				title: "GPT-OZ 4"
				background: c(42 43 45)

				lr(
					background: c(42 43 45)

					td(
						background: c(42 43 45)
						glue: nw
						padx: 50
						0: label(
							text: "History"
							foreground: white
							glue: nwe
							pady: 10
							background: c(42 43 45)
						)
						1: {GetHistoryLabel}
					)

					td(
						height: 300
						width: 400
						background: c(52 53 65)
						padx: 10
						% pady:30

						label(
							text: "GPT-OZ 4"
							foreground: white
							glue: nswe
							pady: 10
							background: c(52 53 65)
						)

						lr( % three columns
							width: 300
							height: 100
							background: c(52 53 65)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								label(
									text: "Examples"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								label(
									text: "Tesla is ...\nshareholders'\nvictory."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe
								)

								label(
									text: "I am ...\nclose to\npoverty."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe
								)

								label(
									text: "I should...\nresell Twitter."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe
								)
							)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								label(
									text: "Possibilities"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								label(
									text: "Get automatic\nTweets"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe
								)

								label(
									text: "N-Grams\nprediction\nbased"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe
								)

								label(
									text: "Easy and\ncomplete\ntweets"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe
								)
							)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								1: label(
									text: "Limitations"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								2: label(
									text: "Elon Musk\ntweetosphere"
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe
								)

								3: label(
									text: "May produce \nweird \noutput "
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe
								)

								4: label(
									text: "Declarative\nOz only "
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe
								)
							)
						)

						text(
							handle: OutputText
							width: 100
							height: 10
							background: c(52 53 65)
							highlightthickness:0
							foreground: white
							glue: nswe
							wrap: word
							borderwidth: 0
						)

						text(
							glue: nswe
							handle: InputText
							width: 100
							height: 5
							background: c(64 65 79)
							borderwidth: 2
							foreground: white
							wrap: word
						)

						button(
							text: "PREDICT"
							relief: groove
							foreground: c(52 53 65)
							background: white
							width: 10
							glue: s
							action: proc {$}
								{OnPress}
							end
						)

						label(
							text: "@GPT-OZ 4 is under MIT license & still in development.\nNo warranty of work is given and it should be used at your own risk."
							foreground: white
							glue: swe
							pady: 20
							background: c(52 53 65)
						)
					)
				)

				% quit program when window is closed

				action: proc {$}
					{Application.exit 0}
				end
			)

			% window creation

			Window = {QTk.build Description}
			{Window show}

			{InputText tk(insert 'end' "Loading... Please wait.")}

			{InputText bind(
				event: "<Control-s>"
				action: proc {$}
					{OnPress}
				end
			)}

			{History set(1: {GetHistory})}

			% On lance les threads de lecture et de parsing

			SeparatedWordsPort = {NewPort SeparatedWordsStream}
			NbThreads = 4

			{Print "Launch producer threads"}
			{LaunchProducerThreads Files SeparatedWordsPort NbThreads}

			{Print "Consume word stream into n-grams"}
			Ngrams = {ConsumeNgrams 3 SeparatedWordsStream}

			{Print "Done"}

			{InputText set(
				1: ""
			)}
		end
		%%ENDOFCODE%%
	end

	% call main procedure
	{Main}

end
