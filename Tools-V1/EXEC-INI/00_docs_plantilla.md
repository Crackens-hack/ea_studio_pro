[Common]

Common platform settings similar to the Server tab:

    Login — account number. The platform tries to read additional authorization information from a configuration file (server, password and certificate password specified in the parameters described below). If the authorization information for the account is not specified, the platform tries to read it from its own account database;
    Server — address and port number of a trade server separated with a colon;
    Password — password for connecting to the account specified in the Login parameter;
    CertPassword — certificate password. This parameter is required if the extended authentication mode is enabled for the account. If the used certificate is not installed in the operating system storage, its file should be placed in platform_folder/config/certificates/;
    ProxyEnable — allow (1) or prohibit (0) connection through a proxy server;
    ProxyType — type of a proxy server: 0 (SOCKS4), 1 (SOCKS5), 2 (HTTP);
    ProxyAddress — IP address and port of the proxy server separated by a colon;
    ProxyLogin — login for authorizing on a proxy server;
    ProxyPassword — password for authorizing on a proxy server;
    KeepPrivate — saving the password between connections: 1 — to save, 0 — not to save.
    NewsEnable — enable (1) or disable (0) news letters;
    CertInstall —  install (1) or do not install (0) new certificates in the system storage (for extended authentication).
    MQL5Login — account on MQL5.community.
    MQL5Password — password for the specified account on MQL5.community.

[Charts]

Chart settings:

    ProfileLast —  the name of the current profile;
    MaxBars — the maximum number of bars in a chart;
    PrintColor — chart print mode: 1 — color printing, 0 — black-and-white printing;
    SaveDeleted — save (1) or not (0) deleted chart to reopen later.

[Experts]

Expert Advisor settings:

    AllowLiveTrading — enable (1) or disable (0) automated trading using Expert Advisors.
    AllowDllImport — DLL import allowed (1) or not (0);
    Enabled — enable or disable use of Expert Advisors;
    Account — disable (1) or not (0) Expert Advisors when connecting with a different account;
    Profile — disable (1) or not (0) Expert Advisors after change after change of the active profile.

[Objects]

Object settings:

    ShowPropertiesOnCreate — show (1) or do not show (0) properties of objects being created;
    SelectOneClick — select (1) or not (0) objects at a single mouse click;
    MagnetSens — docking sensitivity of objects;

[Email]

Email settings:

    Enable — enable (1) or disable (0) use of email;
    Server — address of the SMTP server;
    Auth — encrypted information for authentication on the mail server;
    Login — login for the SMTP server;
    Password — password for the SMTP server;
    From — sender's name and address;
    To — recipient's name and address.

[StartUp]

Settings of Expert Advisors and scripts, that open automatically when you start the platform:

    Expert — file name of the Expert Advisor that opens automatically when you start the platform. The Expert Advisor runs on the chart that opens in accordance with the Symbol and Period parameters. If the Symbol parameter is not set, no additional chart will be opened in the platform. The Expert Advisor will run on the first chart of the current profile in this case. If the current profile has no charts, the Expert Advisor will not be started. If the Expert parameter is not set, no Expert Advisors will be started.
    Symbol — the symbol of the chart that opens straight after the platform start. An Expert Advisor or a script will be added to this chart. No information about this additional chart will be saved as the platform is closed. During the next start of the platform without the configuration file, this chart will not be opened. If this parameter is not set, no additional chart will be opened.
    Period — the timeframe of the chart, to which an Expert Advisor or a script will be added (any of the 21 periods available in the platform). If the parameter is not set, default H1 is used.
    Template — the name of the template to be applied to the chart.
    ExpertParameters — the name of the file that contains Expert Advisor parameters. The file must be located in the folder MQL5\presets of the platform data directory. If this parameter is not set, default settings will be used.
    Script — the name of the script that opens automatically when you start the platform. Scripts are run by the same rules as Expert Advisor.
    ScriptParameters — the name of the file that contains script parameters. The file must be located in the folder MQL5\presets of the platform data directory. If this parameter is not set, default settings will be used.

    ShutdownTerminal — enable/disable trading platform shutdown upon completion of script operation (0 — disable, 1 — enable). If this parameter is not set, the value "0" is used (shutdown disabled). The parameter is used for scripts only, other program types are not supported.

[Tester]

Parameters of testing that starts automatically when you run the platform:

    Expert — the file name of the Expert Advisor that will automatically run in the testing (optimization) mode. If this parameter is not present, testing will not run.
    ExpertParameters — the name of the file that contains Expert Advisor parameters. This file must be located in the MQL5\Profiles\Tester folder of the platform installation directory.
    Symbol — the name of the symbol that will be used as the main testing symbol. If this parameter is not added, the last selected symbol in the tester is used.
    Period — testing chart period (any of the 21 periods available in the platform). If the parameter is not set, default H1 is used.
    Login — this parameter communicates to the Expert Advisor the value of an account, on which testing is allegedly performed. The need for this parameter is set in the source MQL5 code of the Expert Advisor (in the AccountInfoInteger function).
    Model — tick generation mode (0 — "Every tick", 1 — "1 minute OHLC", 2 — "Open price only", 3 — "Math calculations", 4 — "Every tick based on real ticks"). If this parameter is not specified, Every Tick mode is used.
    ExecutionMode — trading mode emulated by the strategy tester (0 — normal, -1 — with a random delay in the execution of trading orders, >0 — trade execution delay in milliseconds, it cannot exceed 600 000).
    Optimization — enable/disable optimization, its type (0 — optimization disabled, 1 — "Slow complete algorithm", 2 — "Fast genetic based algorithm", 3 — "All symbols selected in Market Watch").
    OptimizationCriterion — optimization criterion: (0 — the maximum balance value, 1 — the maximum value of product of the balance and profitability, 2 — the product of the balance and expected payoff, 3 — the maximum value of the expression (100% - Drawdown)*Balance, 4 — the product of the balance and the recovery factor, 5 — the product of the balance and the Sharpe Ratio, 6 — a custom optimization criterion received from the OnTester() function in the Expert Advisor), 7 — the maximum of complex criterion.
    FromDate — starting date of the testing range in format YYYY.MM.DD. If this parameter is not set, the date from the corresponding field of the strategy tester will be used.
    ToDate — end date of the testing range in format YYYY.MM.DD. If this parameter is not set, the date from the corresponding field of the strategy tester will be used.
    ForwardMode — forward testing mode (0 — off, 1 — 1/2 of the testing period, 2 — 1/3 of the testing period, 3 — 1/4 of the testing period, 4 — custom interval specified using the ForwardDate parameter).
    ForwardDate — starting date of forward testing in the format YYYY.MM.DD. The parameter is valid only if ForwardMode=4.
    Report — the name of the file to save the report on testing or optimization results. The file is created in the trading platform directory. You can specify a path to save the file, relative to this directory, for example, \reports\tester.htm. The subdirectory where the report is saved should exist. If no extension is specified in the file name, the ".htm" extension is automatically used for testing reports, and ".xml" is used for optimization reports. If this parameter is not set, the testing report will not be saved as a file. If forward testing is enabled, its results will be saved in a separate file with the ".forward" suffix. For example, tester.forward.htm.
    ReplaceReport — enable/disable overwriting of the report file (0 — disable, 1 — enable). If overwriting is forbidden and a file with the same name already exists, a number in square brackets will be added to the file name. For example, tester[1].htm. If this parameter is not set, default 0 is used (overwriting is not allowed).
    ShutdownTerminal — enable/disable platform shutdown after completion of testing (0 — disable, 1 — enable). If this parameter is not set, the "0" value is used (shutdown disabled). If the testing/optimization process is manually stopped by a user, the value of this parameter is automatically reset to 0.
    Deposit — initial deposit for testing optimization. The amount is specified in the account deposit currency. If the parameter is not specified, a value from the appropriate field of the strategy tester is used.
    Currency — deposit currency for testing/optimization purposes. Specified as a three-letter name, e.g. EUR, USD, CHF etc. Please note that cross rates for converting profit and margin to the specified deposit currency must be available on the account, to ensure proper testing. If the parameter is not specified, a value from the appropriate field of the strategy tester is used.
    Leverage — leverage for testing/optimization. For example, 1:100. If the parameter is not specified, a leverage from the appropriate field of the strategy tester is used.
    UseLocal — enable/disable the use of local agents for testing and optimization (0 — disable, 1 — enable). If the parameter is not specified, current platform settings are used.
    UseRemote — enable/disable use of remote agents for testing and optimization (0 — disable, 1 — enable). If the parameter is not specified, current platform settings are used.
    UseCloud — enable/disable use of agents from the MQL5 Cloud Network (0 — disable, 1 — enable). If the parameter is not specified, current platform settings are used.
    Visual — enable (1) or disable (0) the visual test mode. If the parameter is not specified, the current setting is used.
    Port — the port, on which the local testing agent is running. The port should be specified for the parallel start of testing on different agents. For example, you can run parallel tests of the same Expert Advisor with different parameters. During a single test port can be omitted.

    Input parameters from the file specified in ExpertParameters are used for testing/optimization.
    If the ExpertParameters setup is not available, parameters from the file Expert_name.set located in [platform_folder]\MQL5\Profiles\Tester are used. The last specified set of input parameters of an Expert Advisor is automatically saved in this file.
    If there is no such file, then the default parameters specified in the Expert Advisor code are used for testing. Optimization is not possible.
    To create or edit the set of parameters, select the Expert Advisor on the Settings tab of the strategy tester, and specify input parameters and their modification range on the corresponding tab.

Example of a Configuration File

[Common]

Login=1000575

ProxyEnable=0

ProxyType=0

ProxyAddress=192.168.0.1:3128

ProxyLogin=10

ProxyPassword=10

KeepPrivate=1

NewsEnable=1

CertInstall=1

 

[Charts]

ProfileLast=Euro

MaxBars=50000

PrintColor=0

SaveDeleted=1

 

[Experts]

AllowLiveTrading=0

AllowDllImport=0

Enabled=1

Account=0

Profile=0

 

[Objects]

ShowPropertiesOnCreate=0

SelectOneClick=0

MagnetSens=10

 

;+------------------------------------------------------------------------------+

;|  Running an EA and/or script on the specified chart at the platform start    |

;+------------------------------------------------------------------------------+

[StartUp]

;--- The Expert Advisor is located in platform_data_directory\MQL5\Experts\Examples\MACD\

Expert=Examples\MACD\MACD Sample

;--- EA start parameters are available in platform_data_directory\MQL5\Presets\

ExpertParameters=MACD Sample.set

;--- The script is located in platform_data_directory\MQL5\Scripts\Examples\ObjectSphere\

Script=Examples\ObjectSphere\SphereSample

;--- Symbol chart, which will be opened when you start the platform, and EA and/or script will run on it

Symbol=EURUSD

;--- Chart timeframe, which will be opened when you start the platform, and EA and/or script will run on it

Period=M1

;--- The template to apply to a chart is located in platform_installation_directory\Profiles\Templates

Template=macd.tpl

;--- Set automatic platform shutdown upon completion of script operation

ShutdownTerminal=1

 

;+------------------------------------------------------------------------------+

;| Start Expert Advisor testing or optimization                                 |

;+------------------------------------------------------------------------------+

[Tester]

;--- The Expert Advisor is located in platform_data_directory\MQL5\Experts\Examples\MACD\

Expert=Examples\MACD\MACD Sample

;--- The Expert Advisor parameters are available in platform_installatoin_directory\MQL5\Profiles\Tester\

ExpertParameters=macd sample.set

;--- The symbol for testing/optimization

Symbol=EURUSD

;--- The timeframe for testing/optimization

Period=M1

;--- Emulated account number

Login=123456

;--- Initial deposit

Deposit=10000

;--- Leverage for testing

Leverage=1:100

;--- The "All Ticks" mode

Model=0

;--- Execution of trade orders with a random delay

ExecutionMode=1

;--- Genetic optimization

Optimization=2

;--- Optimization criterion - Maximum balance value

OptimizationCriterion=0

;--- Dates of beginning and end of the testing range

FromDate=2011.01.01

ToDate=2011.04.01

;--- Custom mode of forward testing

ForwardMode=4

;--- Start date of forward testing

ForwardDate=2011.03.01

;--- A file with a report will be saved to the folder platform_installation_directory

Report=test_macd

;--- If the specified report already exists, it will be overwritten

ReplaceReport=1

;--- Set automatic platform shutdown upon completion of testing/optimization

ShutdownTerminal=1