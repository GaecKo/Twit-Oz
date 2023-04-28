% vim: set nospell
% vim: colorscheme gruvbox
% vim: set background='dark'

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
	% === === == === ===

	% /!\ Fonction testee /!\
	% @pre: les threads sont "ready"
	% @post: Fonction appellee lorsqu on appuie sur le bouton de prediction
	%		  Affiche la prediction la plus probable du prochain mot selon les deux derniers mots entres
	% @return: Retourne une liste contenant la liste du/des mot(s) le(s) plus probable(s) accompagnee de
	%			 la probabilite/frequence la plus elevée.
	%			 La valeur de retour doit prendre la forme:
	%						<return_val> := <most_probable_words> '|' <probability/frequence> '|' nil
	%						<most_probable_words> := <atom> '|' <most_probable_words>
	%														 | nil
	%						<probability/frequence> := <int> | <float>

	fun {Press}
		local In Out in
			{InputText get(1: In)}
			Out = {VirtualString.toString In#"Will have to be set"}
			{OutputText set(1: {String.toAtom Out})}
			{AddHistory In Out}
		end
		0
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

	proc {ParseTweet P Tweet}
		Tokens = {String.tokens Tweet & }
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

	% add word to dictionnary
	% TODO explain this all better

	proc {AddToDict Word Next ?Dict}
		Counts = {Dictionary.condGet Dict Word {Dictionary.new}}
		NextCount = {Dictionary.condGet Counts Next 0}
	in
		{Dictionary.put Counts Next NextCount + 1}
		{Dictionary.put Dict Word Counts}
	end

	% consume the tweet stream
	% a stream basically acts as a big list
	% TODO find a better name for this than "Dict"

	proc {ConsumeAux S ?Dict}
		case S
			of Word | T then
				if Word \= thistokenshouldneverappearinthetweets then
					case T
						of nil then skip
						[] Next | _ then
							{AddToDict Word Next Dict}
							{ConsumeAux T Dict}
						else skip
					end
				end
			else skip
		end
	end

	fun {Consume S}
		Dict = {Dictionary.new}
	in
		{ConsumeAux S Dict}
		Dict
	end

	% Ajouter vos fonctions et procédures auxiliaires ici

	proc {SetInOut In Out}
		% Set InputText to In and OutputText to Out
		{InputText set(1: In)}
		{OutputText set(1: Out)}
	end

	fun {GetHistory}
		F = {New TextFile init(name: 'history.txt' flags: [read])}
	in
		{History F nil}
	end

	fun {History F Acc}
		S = {F getS($)}
		Line
	in
		if S == false then
			Acc
		else
			Line = {String.tokens S 124} % S split with "|"
			{History F Line | Acc}
		end
	end

	proc {AddHistory Input Output}
		% Append to history Input|Output\n
		F = {New TextFile init(name: 'history.txt' flags: [read write])}
		Line = {Append {Append Input "|"} Output} % Input|Output
		WDesc
	in
		% XXX can't do this for the moment - cf. https://github.com/mozart/mozart2/pull/345
		% {F seek(whence: 'end' offset: 0)}

		{F getDesc(WDesc _)}
		{OS.lSeek WDesc 'SEEK_END' 0 _}

		{F putS(Line)}
		{F close}
	end

	fun {CreatePanel}
		% gives the left panel history
		Panel = td(
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
		)
	in
		{AddPanel {GetHistory} Panel 1}
	end

	fun	{AddPanel Lst Acc Index}
		% Creates a record: ...(... 1: button(...) 2: button(...))
		case Lst
			of nil then
				Acc
			[] (H1|H2)|T then
				local Buttn in
					Buttn = button(
						width: 15
						background: c(42 43 45)
						glue: nwe
						text: H1
						relief: raised
						action: proc {$}
							{SetInOut H1 H2.1}
						end
					)
					{AddPanel T {AdjoinAt Acc Index Buttn} Index + 1}
				end
			else
				0	
		end
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

	fun {GetFiles L} % L = {OS.getDir TweetsFolder}
		% Returns a list of the path to all files in tweets/: part_1.txt|...|nil
		case L
			of nil then nil
			[] H|T then {String.toAtom {Append "tweets/" H}}|{GetFiles T} % gives: 'tweets/fileX.txt'
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

	fun {FindInSequence SequenceList SentenceList Acc Initial}
		%% Check for Sequence within Sentence:
		%% [Hello I] [Sir Hello I am happy] -> [Hello I] [Hello I am happy] -> [I] [I am happy] -> [am] added
		SenLen = {List.length SentenceList}
		SeqLen = {List.length SequenceList}
	in
		local Found Word in
			if SenLen < (SeqLen + 1) then % if not possible because at end of sentence
				Acc
			else
				if SeqLen == 1 then
					if {Strcasecmp SequenceList.1 SentenceList.1} == 1 then
						Word = SentenceList.2.1 % next word found !
						Found = 1
					else
						Word = nil
						Found = 0
					end
				else
					Word = nil
					Found = 0
				end
	
				if SeqLen == 0 then
					if Found == 1 then
						{FindInSequence Initial SentenceList Word|Acc Initial} % restart search with initial sequence
					else
						{FindInSequence Initial SentenceList Acc Initial}
					end
	
				elseif {Strcasecmp SequenceList.1 SentenceList.1} == 1 then
					if Found == 1 then % add Word to list and continue checking for equivalence with further words in tail of sentence
						{FindInSequence SequenceList.2 SentenceList.2 Word|Acc Initial}
					else
						{FindInSequence SequenceList.2 SentenceList.2 Acc Initial}
					end
	
				else
					{FindInSequence SequenceList SentenceList.2 Acc Initial} % if no correspondance, continue checking for occurence in tail of sentence, keeping the same sequence list
				end
			end
		end
	end

	fun {FindinString SequenceString SentenceString}
		%% Strings is a String: "word1 word2",
		%% Sentence a List of String: "word1 word2 word3 word4"
		SentenceList = {String.tokens SentenceString 32} % = Sentence.split(" ")
		SequenceList = {String.tokens SequenceString 32}
	in
		{FindInSequence SequenceList SentenceList nil SequenceList}
	end

	% Procedure principale qui cree la fenetre et appelle les differentes procedures et fonctions
	proc {Main}
		TweetsFolder = {GetSentenceFolder}
		Files = {GetFiles {OS.getDir TweetsFolder}} % Files = 'tweets/part1.txt' '|' ... '|' nil
		Dict
	in
		% Fonction d'exemple qui liste tous les fichiers
		% contenus dans le dossier passe en Argument.
		% Inspirez vous en pour lire le contenu des fichiers
		% se trouvant dans le dossier
		% N'appelez PAS cette fonction lors de la phase de
		% soumission !!!

		% {PrintFilesContent Files} % Just prints all the content of files
		%local R in
			% R = {FindinString "hello" "hello sir i am"}
			% R = {FindinString "I am" "Today I am with my best friend Roberto, I am glad :)))"} % -> [with glad]

			% {Browse R}
		% {TestFile}
		%end

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
						{CreatePanel}

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

				% TODO we can use R now, it contains the result of the search in files
			end

			% On lance les threads de lecture et de parsing

			SeparatedWordsPort = {NewPort SeparatedWordsStream}
			NbThreads = 4

			{Print "Launch producer threads"}
			{LaunchProducerThreads Files SeparatedWordsPort NbThreads}

			{Print "Consume words stream"}
			Dict = {Consume SeparatedWordsStream}

			{Print "Done"}
			{Browse Dict}

			{InputText set(
				1: ""
			)}
		end
	end

	% call main procedure

	{Main}
end
