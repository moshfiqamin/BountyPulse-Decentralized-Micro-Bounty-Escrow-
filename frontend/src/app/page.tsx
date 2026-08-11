"use client";

import { useState, useEffect } from "react";
import { ethers, BrowserProvider } from "ethers";
import { CONTRACT_ADDRESS, CONTRACT_ABI } from "@/lib/contract";
import { uploadToIPFS } from "@/lib/ipfs";
import { Loader2 } from "lucide-react";

interface UserProfile {
  name: string;
  role: number;
  reputation: number;
  isRegistered: boolean;
}

interface Bid {
  freelancer: string;
  quote: bigint;
}

interface Bounty {
  id: number;
  client: string;
  maxBudget: bigint;
  ipfsBountyDetailsHash: string;
  status: number;
  selectedFreelancer: string;
  acceptedBidAmount: bigint;
  ipfsWorkFileHash: string;
  bids: Bid[];
}

export default function Home() {
  const [provider, setProvider] = useState<BrowserProvider | null>(null);
  const [signer, setSigner] = useState<ethers.Signer | null>(null);
  const [account, setAccount] = useState<string>("");

  const [user, setUser] = useState<UserProfile | null>(null);
  const [isRegistering, setIsRegistering] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [roleInput, setRoleInput] = useState<number>(1);

  const [loading, setLoading] = useState(false);
  const [bounties, setBounties] = useState<Bounty[]>([]);

  const [budgetInput, setBudgetInput] = useState("");
  const [detailsInput, setDetailsInput] = useState("");
  const [bidInputs, setBidInputs] = useState<{[key: number]: string}>({});
  const [workInputs, setWorkInputs] = useState<{[key: number]: string}>({});

  useEffect(() => {
    let isMounted = true;
    if (window.ethereum && isMounted) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const p = new ethers.BrowserProvider(window.ethereum as any);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setProvider(p);
    }
    return () => {
      isMounted = false;
    };
  }, []);

  const fetchBounties = async (s: ethers.Signer) => {
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, s);
    const count = await contract.bountyCount();
    const fetched: Bounty[] = [];
    for (let i = 0; i < Number(count); i++) {
      const b = await contract.bounties(i);
      const bids = await contract.getBids(i);
      fetched.push({
        id: i,
        client: b.client,
        maxBudget: b.maxBudget,
        ipfsBountyDetailsHash: b.ipfsBountyDetailsHash,
        status: Number(b.status),
        selectedFreelancer: b.selectedFreelancer,
        acceptedBidAmount: b.acceptedBidAmount,
        ipfsWorkFileHash: b.ipfsWorkFileHash,
        bids: bids
      });
    }
    setBounties(fetched);
  };

  const connectWallet = async () => {
    if (!provider) return alert("Please install MetaMask!");
    setLoading(true);
    try {
      const accounts = await provider.send("eth_requestAccounts", []);
      setAccount(accounts[0]);
      const s = await provider.getSigner();
      setSigner(s);

      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, s);
      const u = await contract.users(accounts[0]);
      if (u.isRegistered) {
        setUser({
          name: u.name,
          role: Number(u.role),
          reputation: Number(u.reputation),
          isRegistered: u.isRegistered
        });
        await fetchBounties(s);
      }
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  const registerUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!signer) return;
    setIsRegistering(true);
    try {
      const avatarHash = await uploadToIPFS("dummy_avatar");
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.register(nameInput, roleInput, avatarHash);
      await tx.wait();

      const u = await contract.users(account);
      setUser({
        name: u.name,
        role: Number(u.role),
        reputation: Number(u.reputation),
        isRegistered: u.isRegistered
      });
      await fetchBounties(signer);
    } catch (error) {
      console.error(error);
      alert("Registration failed");
    }
    setIsRegistering(false);
  };

  const postBounty = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!signer) return;
    setLoading(true);
    try {
      const detailsHash = await uploadToIPFS(detailsInput);
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const budgetWei = ethers.parseEther(budgetInput);
      const tx = await contract.postBounty(budgetWei, detailsHash);
      await tx.wait();
      alert("Bounty posted successfully!");
      setBudgetInput("");
      setDetailsInput("");
      await fetchBounties(signer);
    } catch (error) {
      console.error(error);
      alert("Failed to post bounty");
    }
    setLoading(false);
  };

  const placeBid = async (bountyId: number) => {
    if (!signer) return;
    setLoading(true);
    try {
      const quoteWei = ethers.parseEther(bidInputs[bountyId] || "0");
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.bid(bountyId, quoteWei);
      await tx.wait();
      alert("Bid placed!");
      await fetchBounties(signer);
    } catch (e) {
      console.error(e);
      alert("Failed to place bid. Ensure reputation >= 40 and quote <= budget.");
    }
    setLoading(false);
  };

  const fundBounty = async (bountyId: number, bidIndex: number, amount: bigint) => {
    if (!signer) return;
    setLoading(true);
    try {
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.fundBounty(bountyId, bidIndex, { value: amount });
      await tx.wait();
      alert("Bounty funded and locked!");
      await fetchBounties(signer);
    } catch (e) {
      console.error(e);
      alert("Failed to fund bounty.");
    }
    setLoading(false);
  };

  const submitWork = async (bountyId: number) => {
    if (!signer) return;
    setLoading(true);
    try {
      const workHash = await uploadToIPFS(workInputs[bountyId] || "work");
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.submitWork(bountyId, workHash);
      await tx.wait();
      alert("Work submitted!");
      await fetchBounties(signer);
    } catch (e) {
      console.error(e);
      alert("Failed to submit work.");
    }
    setLoading(false);
  };

  const approveWork = async (bountyId: number) => {
    if (!signer) return;
    setLoading(true);
    try {
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.approveWork(bountyId);
      await tx.wait();
      alert("Work approved and funds allocated!");
      await fetchBounties(signer);
    } catch (e) {
      console.error(e);
      alert("Failed to approve work.");
    }
    setLoading(false);
  };

  const disputeBounty = async (bountyId: number) => {
    if (!signer) return;
    setLoading(true);
    try {
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.disputeBounty(bountyId);
      await tx.wait();
      alert("Dispute raised!");
      await fetchBounties(signer);
    } catch (e) {
      console.error(e);
      alert("Failed to raise dispute.");
    }
    setLoading(false);
  };

  const claimFunds = async () => {
    if (!signer) return;
    setLoading(true);
    try {
      const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
      const tx = await contract.claimFunds();
      await tx.wait();
      alert("Funds claimed!");
    } catch (e) {
      console.error(e);
      alert("Failed to claim funds.");
    }
    setLoading(false);
  };

  return (
    <main className="min-h-screen p-8 bg-gray-50 text-gray-900 font-sans">
      <div className="max-w-4xl mx-auto space-y-8">

        {/* Header */}
        <header className="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <div>
            <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-600 to-indigo-600">
              BountyPulse
            </h1>
            <p className="text-gray-500 mt-1">Decentralized Micro-Bounty Platform</p>
          </div>
          <div>
            {!account ? (
              <button
                onClick={connectWallet}
                disabled={loading}
                className="px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                aria-label="Connect your wallet"
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                {loading ? "Connecting..." : "Connect Wallet"}
              </button>
            ) : (
              <div className="px-4 py-2 bg-indigo-50 text-indigo-700 font-medium rounded-xl border border-indigo-100 text-sm flex gap-4 items-center">
                <span>{account.slice(0, 6)}...{account.slice(-4)}</span>
                {user && (
                  <button onClick={claimFunds} className="text-xs bg-indigo-600 text-white px-2 py-1 rounded">Claim Funds</button>
                )}
              </div>
            )}
          </div>
        </header>

        {account && !user && (
          <section className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-semibold mb-4">Complete Your Profile</h2>
            <form onSubmit={registerUser} className="space-y-4 max-w-md">
              <div>
                <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
                  Display Name <span className="text-red-500">*</span>
                </label>
                <input
                  id="name"
                  type="text"
                  value={nameInput}
                  onChange={e => setNameInput(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                  placeholder="Enter your name"
                  required
                  aria-required="true"
                />
              </div>
              <div>
                <label htmlFor="role" className="block text-sm font-medium text-gray-700 mb-1">
                  Account Type
                </label>
                <select
                  id="role"
                  value={roleInput}
                  onChange={e => setRoleInput(Number(e.target.value))}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                >
                  <option value={1}>Client (Post Bounties)</option>
                  <option value={2}>Freelancer (Complete Work)</option>
                </select>
              </div>
              <button
                type="submit"
                disabled={isRegistering}
                className="w-full px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                aria-label={isRegistering ? "Registering account..." : "Register account"}
              >
                {isRegistering && <Loader2 className="w-4 h-4 animate-spin" />}
                {isRegistering ? "Registering..." : "Register"}
              </button>
            </form>
          </section>
        )}

        {user && user.role === 1 && (
          <section className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-semibold mb-4">Post a New Bounty</h2>
            <form onSubmit={postBounty} className="space-y-4 max-w-md">
              <div>
                <label htmlFor="budget" className="block text-sm font-medium text-gray-700 mb-1">
                  Max Budget (ETH) <span className="text-red-500">*</span>
                </label>
                <input
                  id="budget"
                  type="number"
                  step="0.0001"
                  value={budgetInput}
                  onChange={e => setBudgetInput(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-indigo-500 outline-none transition-all"
                  placeholder="e.g. 0.05"
                  required
                />
              </div>
              <div>
                <label htmlFor="details" className="block text-sm font-medium text-gray-700 mb-1">
                  Project Details <span className="text-red-500">*</span>
                </label>
                <textarea
                  id="details"
                  value={detailsInput}
                  onChange={e => setDetailsInput(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-indigo-500 outline-none transition-all h-24 resize-none"
                  placeholder="Describe the task..."
                  required
                />
              </div>
              <button
                type="submit"
                disabled={loading}
                className="w-full px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-xl transition-all disabled:opacity-50 flex justify-center items-center gap-2"
                aria-label="Post bounty"
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                {loading ? "Posting..." : "Post Bounty"}
              </button>
            </form>
          </section>
        )}

        {user && (
          <section className="space-y-6">
            <h2 className="text-2xl font-bold">Bounty Board</h2>
            {bounties.map((b) => (
              <div key={b.id} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <span className="text-xs font-bold px-2 py-1 bg-gray-100 rounded text-gray-600">ID: {b.id}</span>
                    <h3 className="text-lg font-semibold mt-2">Max Budget: {ethers.formatEther(b.maxBudget)} ETH</h3>
                    <p className="text-sm text-gray-500 mt-1">Status: {["Open", "Locked", "Disputed", "Resolved"][b.status]}</p>
                    <p className="text-sm text-gray-500 break-all">Details (IPFS): {b.ipfsBountyDetailsHash}</p>
                  </div>
                </div>

                {b.status === 0 && user.role === 2 && (
                  <div className="mt-4 pt-4 border-t border-gray-100 flex gap-2">
                    <input
                      type="number"
                      step="0.0001"
                      placeholder="Quote (ETH)"
                      value={bidInputs[b.id] || ""}
                      onChange={e => setBidInputs({...bidInputs, [b.id]: e.target.value})}
                      className="px-3 py-1.5 rounded border focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
                    />
                    <button
                      onClick={() => placeBid(b.id)}
                      disabled={loading}
                      className="px-4 py-1.5 bg-indigo-600 text-white rounded font-medium text-sm disabled:opacity-50 flex items-center gap-2"
                      aria-label="Place Bid"
                    >
                      {loading && <Loader2 className="w-3 h-3 animate-spin" />} Place Bid
                    </button>
                  </div>
                )}

                {b.status === 0 && b.bids && b.bids.length > 0 && (
                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <h4 className="text-sm font-semibold mb-2">Bids</h4>
                    <div className="space-y-2">
                      {b.bids.map((bid, i) => (
                        <div key={i} className="flex justify-between items-center text-sm p-2 bg-gray-50 rounded">
                          <span>{bid.freelancer.slice(0,6)}... bids {ethers.formatEther(bid.quote)} ETH</span>
                          {user.role === 1 && b.client.toLowerCase() === account.toLowerCase() && (
                            <button
                              onClick={() => fundBounty(b.id, i, bid.quote)}
                              disabled={loading}
                              className="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50"
                              aria-label="Accept and Fund"
                            >
                              Accept & Fund
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {b.status === 1 && b.selectedFreelancer.toLowerCase() === account.toLowerCase() && user.role === 2 && (
                  <div className="mt-4 pt-4 border-t border-gray-100 flex gap-2">
                     <input
                      type="text"
                      placeholder="Work Content or Link"
                      value={workInputs[b.id] || ""}
                      onChange={e => setWorkInputs({...workInputs, [b.id]: e.target.value})}
                      className="flex-1 px-3 py-1.5 rounded border focus:ring-2 focus:ring-indigo-500 outline-none text-sm"
                    />
                    <button
                      onClick={() => submitWork(b.id)}
                      disabled={loading}
                      className="px-4 py-1.5 bg-blue-600 text-white rounded font-medium text-sm disabled:opacity-50 flex items-center gap-2"
                      aria-label="Submit Work"
                    >
                      {loading && <Loader2 className="w-3 h-3 animate-spin" />} Submit Work
                    </button>
                  </div>
                )}

                {b.status === 1 && b.client.toLowerCase() === account.toLowerCase() && user.role === 1 && b.ipfsWorkFileHash && (
                  <div className="mt-4 pt-4 border-t border-gray-100 flex gap-2 justify-between items-center">
                    <p className="text-sm text-gray-700">Work submitted (IPFS): {b.ipfsWorkFileHash}</p>
                    <div className="flex gap-2">
                      <button
                        onClick={() => approveWork(b.id)}
                        disabled={loading}
                        className="px-3 py-1.5 bg-green-600 text-white rounded font-medium text-sm disabled:opacity-50"
                        aria-label="Approve Work"
                      >
                        Approve
                      </button>
                      <button
                        onClick={() => disputeBounty(b.id)}
                        disabled={loading}
                        className="px-3 py-1.5 bg-red-600 text-white rounded font-medium text-sm disabled:opacity-50"
                        aria-label="Dispute Work"
                      >
                        Dispute
                      </button>
                    </div>
                  </div>
                )}

              </div>
            ))}
            {bounties.length === 0 && (
              <p className="text-gray-500 italic">No bounties posted yet.</p>
            )}
          </section>
        )}

      </div>
    </main>
  );
}
