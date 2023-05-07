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
	History
	% === === == === ===

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

	fun {HighestProbAux Keys Probs MaxCount MaxKey}
		Count
		NewMaxCount
		NewMaxKey
	in
		case Keys
			of H | T then
				Count = {Dictionary.get Probs H}

				if Count > MaxCount then
					NewMaxKey = H
					NewMaxCount = Count
				else
					NewMaxKey = MaxKey
					NewMaxCount = MaxCount
				end

				{HighestProbAux T Probs NewMaxCount NewMaxKey}
			[] nil then
				MaxKey
		end
	end

	fun {HighestProb Probs}
		{HighestProbAux {Dictionary.keys Probs} Probs 0 nil}
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
	in
		if {Dictionary.member Ngram Key} then
			{Dictionary.get Ngram Key}
		elseif N == 1 then
			{Dictionary.new} % XXX Should we make this return the most common word in the whole dataset then?
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
		{HighestProb Probs}
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
		In Out
		Probs MaxKey MaxCount Entries MaxEntries MaxKeys
	in
		{InputText get(1: In)}
		Out = {VirtualString.toString In # " " # {Predict In}}
		{OutputText set(1: {String.toAtom Out})}
		{AddHistory In}
		{RefreshHistory In}
		{InputText set(1: Out)}
		% return

		Probs = {PredictProbs In}
		MaxKey = {HighestProb Probs}
		MaxCount = {Dictionary.condGet Probs MaxKey 0}
		Entries = {Dictionary.entries Probs}

		MaxEntries = {List.filter Entries fun {$ Entry}
			Entry.2 == MaxCount
		end}

		MaxKeys = {List.map MaxEntries fun {$ Entry}
			Entry.1
		end}

		0 %s[MaxKeys MaxCount]
	end

	proc {OnPress ?R}
		R = {Press}
	end

	% return a list of the tweets within a file (without '\n'): tweet_N | tweet_N-1 | ... | nil

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

	proc {ParseTweet P Tweet}
		SanitizedTweet = {Sanitize Tweet}
		Tokens = {RemoveNil {String.tokens SanitizedTweet & }} 
	in
		{SendTokens P Tokens}
	end

	% go through a list of tweets and parse them

	proc {ParseTweets P Tweets}
		case Tweets
			of H | T then % TODO check if this is TCO-able in Oz
				{ParseTweet P H}
				{ParseTweets P T}
			[] nil then skip
		end
	end

	% read a given part file
	% each file consists of a bunch of tweets, each on their own line

	proc {ReadPart P Name}
		F = {New TextFile init(name: Name flags: [read])}
		Tweets = {GetFileLines F}
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
			thread {ReadThread Files {List.length Files} P N TotalN} end
			% {ReadThread Files {List.length Files} P N TotalN}
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
						ngram(Key: freqs(Word: 1))
					else
						{ConsumeNgramFreqs N - 1 T Key # Word # " "}
					end
				end
			else nil
		end
	end

	fun {ConsumeNgram N S} % returns full ngram record
		case S
			of Word | T then
				if Word \= thistokenshouldneverappearinthetweets then
					local
						Cur = {ConsumeNgram N T}
						Ngram = {ConsumeNgramFreqs N T ""}
					in
						{CombineNgrams Cur Ngram}
					end
				else
					nil
				end
			else nil
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
		{Print TweetsFolder}
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
			% R will store {Press} result

			local R in
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
										text: "I am ...\nclose\npoverty."
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
										text: "2-grammes\nprediction\nbased"
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
										text: "Maximum \nresponse\nof 100 words"
										foreground: white
										background: c(64 65 79)
										pady: 8
										glue: nwe
									)

									4: label(
										text: "Oz slowness\n& bugs"
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
									{OnPress R}
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
						{OnPress R}
					end
				)}
			end
		
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
	end

	% call main procedure

	{Main}
end
