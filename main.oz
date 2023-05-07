% vim: nospell

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

	% Pour ouvrir les fichiers

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
	% === === == === ===

	% binary tree operations
	% TODO should we change the names of these record keys (features)? could this improve performance?
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
	% this consists of replacing all non-alphanumerical characters by spaces and lowercasing them

	fun {Sanitize String}
		{List.map String fun {$ C}
			if {Char.isAlpha C} == false then
				(& )
			else
				{Char.toLower C}
			end
		end}
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

	fun {FindLastTwo L}
		{FindLastTwoAux L.2 L.1}
	end

	fun {FindLastTwoAux Tail Previous}
		case Tail
			of nil then nil
			[] H|T then
				if T == nil then
					[Previous H]
				else
					{FindLastTwoAux T H}
				end
		end
	end 

	% /!\ Fonction testee /!\
	% @pre: les threads sont "ready"
	% @post: Fonction appellee lorsqu on appuie sur le bouton de prediction
	%		  Affiche la prediction la plus probable du prochain mot selon les deux derniers mots entres
	% @return: Retourne une liste contenant la liste du/des mot(s) le(s) plus probable(s) accompagnee de
	%			 la probabilite/frequence la plus elevée.
	%			 La valeur de retour doit prendre la forme:
	%
	%% <return_val>            := <most_probable_words> '|' <probability/frequence> '|' nil
	%% <most_probable_words>   := <atom> '|' <most_probable_words>
	%						| nil
	% 						| <no_word_found>
	%% <no_word_found>         := nil '|' nil

	%% <probability/frequence> := <int> | <float>

	%% Example:
	%% * [[cool swag nice] 0.7]
	%% * [[cool swag nice] 7]
	%% * [[nil] 0]               # should return [nil] in case of no most probable word found

		fun {Press}
			In Out InToUse Return LastTwo
			Probs Highest MaxKey MaxCount Entries MaxEntries MaxKeys
		in
			{InputText get(1: In)}
	
			case In
				of nil then
					Return = [[nil] 0]
				[] H|T then
					Return = nil
					if {List.length {String.tokens In & }} > 2 then
						LastTwo = {FindLastTwo {String.tokens In & }}
						InToUse = {VirtualString.toString LastTwo.1 # " " # LastTwo.2.1}

					elseif {List.length {String.tokens In & }} == 1 then
						Return = [[nil] 0]
					else 
						InToUse = In
					end
			end
	
			if Return \= nil then
				Return
			else
				Out = {VirtualString.toString In # " " # {Predict InToUse}}
				{OutputText set(1: {String.toAtom Out})}
				{Print InToUse}
				% return
	
				Probs = {PredictProbs InToUse}

				if Probs == nil then
					[[nil] 0]
				else
					Highest = {HighestProb Probs}

					MaxKey = Highest.1
					MaxCount = Highest.2.1

					MaxKeys = {KeysWithProb Probs MaxCount}

					{Browse [MaxKeys MaxCount]}
					[MaxKeys MaxCount]
			end
		end
	end

	proc {OnPress}
		_ = {Press}
	end

	% return a list of the tweets within a file (without '\n'): tweet_N | tweet_N-1 | ... | nil
	
	fun {GetFileContent F}
		Content
	in 
		{F read(list: Content size: all)}
		Content
	end
		
	fun {GetFileLinesAux F Acc}
		Tweet = {F getS($)}
	in
		if Tweet == false then
			Acc
		else
			{GetFileLinesAux F Tweet | Acc}
		end
	end

	fun {GetFileLines F}
		{GetFileLinesAux F nil}
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

	% parse tweet into tokens
	% XXX currently, this is just splitting by space - this should be a bit more involved

	fun {RemoveNilAux Tokens Acc} % Tokens is a list of words "..."|"..."|nil|"..."|nil -> remove the nil (appart from the last one of course)
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
	% TODO can I optimize this by only adjoining on one side?

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

	% Decomnentez moi si besoin
	proc {ListAllFiles L}
		case L of nil then skip
		[] H|T then {Print {String.toAtom H}} {ListAllFiles T}
		end
	end

	fun {GetFiles Folder L} % L = {OS.getDir TweetsFolder}
		% Returns a list of the path to all files in tweets/: part_1.txt|...|nil
		case L
			of nil then nil
			[] H|T then {VirtualString.toAtom Folder # "/" # H }|{GetFiles Folder T} % gives: 'tweets/fileX.txt'
		end
	end

	% Useful function for later: {File GetS($)} -> gives the next line etc etc

	fun {Strcasecmp S1 S2}
		% return true if strings are equal regardless of case

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

	% Procedure principale qui cree la fenetre et appelle les differentes procedures et fonctions
	proc {Main}
		TweetsFolder = {GetSentenceFolder}
		Files = {GetFiles TweetsFolder {OS.getDir TweetsFolder}} % Files = 'tweets/part1.txt' '|' ... '|' nil
	in
		% Fonction d'exemple qui liste tous les fichiers
		% contenus dans le dossier passe en Argument.
		% Inspirez vous en pour lire le contenu des fichiers
		% se trouvant dans le dossier
		% N'appelez PAS cette fonction lors de la phase de
		% soumission !!!

		local NbThreads Description Window SeparatedWordsStream SeparatedWordsPort in
			{Property.put print foo(
				width: 1000
				depth: 1000
			)}

			% TODO

			% Creation de l'interface graphique
			Description=td(
					title: "Text predictor"
					lr(text(handle:InputText width:50 height:10 background:white foreground:black wrap:word) button(text:"Predict" width:15 action: proc {$} {OnPress} end))
					text(handle:OutputText width:50 height:10 background:black foreground:white glue:w wrap:word)
					action:proc{$}{Application.exit 0} end % quitte le programme quand la fenetre est fermee
						)
			Window = {QTk.build Description}
			{Window show}

			{InputText tk(insert 'end' "Loading... Please wait.")}

			{InputText bind(
				event: "<Control-s>"
				action: proc {$}
					{OnPress}
				end
			)}

			% On lance les threads de lecture et de parsing

			SeparatedWordsPort = {NewPort SeparatedWordsStream}
			NbThreads = 4

			{Print "Launch producer threads"}
			{LaunchProducerThreads Files SeparatedWordsPort NbThreads}

			{Print "Consume word stream into n-grams"}
			Ngrams = {ConsumeNgrams 2 SeparatedWordsStream}

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
