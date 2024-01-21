import NIOCore
import NIOPosix

let server = try await ServerBootstrap(group: NIOSingletons.posixEventLoopGroup)
    .bind(
        host: "0.0.0.0",
        port: 2048
    ) { channel in
        channel.eventLoop.makeCompletedFuture {
            // Add any handlers for parsing or serializing messages here
            // We don't need any for this echo example

            return try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: NIOAsyncChannel.Configuration(
                    inboundType: ByteBuffer.self, // We'll read the raw bytes from the socket
                    outboundType: ByteBuffer.self // We'll also write raw bytes to the socket
                )
            )
        }
    }

// We create a task group to manage the lifetime of our client connections
// Each client is handled by its own structured task
try await withThrowingDiscardingTaskGroup { group in
    try await server.executeThenClose { clients in
        // Iterate over the clients as an async sequence
        for try await client in clients {
            // Every time we get a new client, we add a new task to the group
            group.addTask {
                // We handle the client in a separate function to keep the main loop clean
                try await handleClient(client)
            }
        }
    }
}

func handleClient(_ client: NIOAsyncChannel<ByteBuffer, ByteBuffer>) async throws {
    try await client.executeThenClose { inboundMessages, outbound in
        // We'll read from the client until the connection closes
        for try await inboundMessage in inboundMessages {
            // Write the message back to the client
            try await outbound.write(inboundMessage)
            return
        }
    }
}
