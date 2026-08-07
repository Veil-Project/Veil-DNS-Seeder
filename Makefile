CXX ?= g++
CXXFLAGS ?= -O3 -g0
LIBS ?= -lcrypto

WARNFLAGS = -Wall -Wno-unused -Wno-sign-compare -Wno-reorder -Wno-comment
OBJS = dns.o bitcoin.o netbase.o protocol.o db.o main.o util.o

dnsseed: $(OBJS)
	$(CXX) -pthread $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

%.o: %.cpp *.h
	$(CXX) -std=c++11 -pthread $(CPPFLAGS) $(CXXFLAGS) $(WARNFLAGS) -c -o $@ $<

clean:
	rm -f *.o dnsseed *.dump *.log *.dat report.xml
